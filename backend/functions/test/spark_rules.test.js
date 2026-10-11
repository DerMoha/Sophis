import {after,before,beforeEach,test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {initializeTestEnvironment,assertFails,assertSucceeds} from '@firebase/rules-unit-testing';
import {doc,collection,getDoc,getDocs,setDoc,updateDoc,deleteDoc,writeBatch,query,where,limit,serverTimestamp,Timestamp} from 'firebase/firestore';
if(!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Emulator required');
let env;
const id='a'.repeat(64);
const defaults=()=>({meals:true,summaries:true,goals:true,paused:false,revision:0,mealGeneration:0,summaryGeneration:0,goalGeneration:0,mealStart:null,summaryStart:null,mealTimeZone:null,summaryTimeZone:null});
const clients=new Map();
const db=(uid)=>{if(!clients.has(uid))clients.set(uid,uid?env.authenticatedContext(uid).firestore():env.unauthenticatedContext().firestore());return clients.get(uid);};
const conn=(uid='alice')=>doc(db(uid),'partnerConnections',id);
const invitation=(uid='alice')=>doc(db(uid),'partnerInvitations',id);
const source=(uid,owner='alice',kind='meals',key='one')=>doc(db(uid),`partnerConnections/${id}/members/${owner}/${kind}/${key}`);
const snapshot={schemaVersion:1,title:'Rice',servings:1,items:[{name:'Rice',calories:200,protein:4,carbs:44,fat:1,fiber:2,portionAmount:150,portionUnit:'g'}]};
async function invite(){await setDoc(invitation(),{inviterId:'alice',displayName:'Alice',createdAt:serverTimestamp(),expiresAt:Timestamp.fromMillis(Date.now()+3600000),consumedBy:null,revoked:false});}
function connectionData(){return {participants:['alice','bob'],inviterId:'alice',status:'pending',revokedAt:null,createdAt:serverTimestamp(),displayNames:{alice:'Alice',bob:'Bob'},settings:{alice:defaults(),bob:defaults()}};}
async function request(patch={}){const batch=writeBatch(db('bob'));batch.update(invitation('bob'),{consumedBy:'bob'});batch.set(conn('bob'),{...connectionData(),...patch});await batch.commit();}
async function connect(){await invite();await request();await updateDoc(conn(),{status:'accepted'});}
async function data(kind='meals',patch={}){
 const s=(await getDoc(conn())).data().settings.alice;
 return {sourceRevision:1,generation:kind==='meals'?s.mealGeneration:s.summaryGeneration,consentRevision:s.revision,originallyLoggedAt:Timestamp.now(),changedAt:Timestamp.now(),localDate:'2026-10-08',timeZone:'Europe/Berlin',deletedAt:null,publishedAt:serverTimestamp(),...(kind==='meals'?{snapshot,mealCategory:'Lunch'}:{calories:200,protein:4,carbs:44,fat:1}),...patch};
}
const mealQuery=(uid='bob',kind='meals',generation=0)=>getDocs(query(collection(db(uid),`partnerConnections/${id}/members/alice/${kind}`),where('generation','==',generation),where('deletedAt','==',null),where('localDate','==','2026-10-08'),where('timeZone','==','Europe/Berlin'),limit(20)));
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-sophis',firestore:{rules:await readFile('../firestore.rules','utf8')}});});
beforeEach(async()=>{await env.clearFirestore();for(const [uid,name]of[['alice','Alice'],['bob','Bob'],['eve','Eve']])await setDoc(doc(db(uid),'partnerProfiles',uid),{accountId:uid,displayName:name});});
after(async()=>{await env?.cleanup();});
test('kept profiles private and rejected forged fields and legacy access',async()=>{
 await assertFails(getDoc(doc(db('bob'),'partnerProfiles','alice')));await assertFails(getDocs(collection(db('alice'),'partnerProfiles')));
 await assertFails(setDoc(doc(db('alice'),'partnerProfiles','alice'),{accountId:'alice',displayName:'Alice',weight:55}));
 await assertFails(getDoc(doc(db(null),'partnerProfiles','alice')));await assertFails(setDoc(doc(db('alice'),'socialPosts','one'),snapshot));
});
test('required mutual acceptance before sharing',async()=>{
 await invite();await assertFails(updateDoc(invitation('bob'),{consumedBy:'bob'}));await request();
 await assertFails(updateDoc(conn('bob'),{status:'accepted'}));await assertFails(getDoc(conn('eve')));
 await assertFails(setDoc(source('alice'),await data()));await updateDoc(conn(),{status:'accepted'});
 await assertSucceeds(setDoc(source('alice'),await data()));await assertSucceeds(getDoc(source('bob')));
});
test('rejected invitation reuse and invented connections',async()=>{
 await invite();for(const patch of[{participants:['alice','bob','eve']},{status:'accepted'},{settings:{alice:{...defaults(),meals:false},bob:defaults()}},{displayNames:{alice:'Forged',bob:'Bob'}}])await assertFails(request(patch));
 await assertFails(setDoc(conn('bob'),connectionData()));await request();await assertFails(getDoc(invitation('eve')));await assertFails(updateDoc(invitation('bob'),{consumedBy:'eve'}));
});
test('revoked unused invitations',async()=>{await invite();await updateDoc(invitation(),{revoked:true});await assertFails(getDoc(invitation('bob')));await assertFails(request());});
test('shared history, totals and goals automatically in both directions',async()=>{
 await connect();const historical=await data('meals',{originallyLoggedAt:Timestamp.fromMillis(0),changedAt:Timestamp.fromMillis(1000)});
 await setDoc(source('alice'),historical);await assertSucceeds(getDoc(source('bob')));
 await setDoc(source('bob','bob'),historical);await assertSucceeds(getDoc(source('alice','bob')));
 await setDoc(source('alice','alice','contributions'),await data('contributions',{originallyLoggedAt:Timestamp.fromMillis(0)}));assert.equal((await mealQuery('bob','contributions')).size,1);
 const goal={goals:{calories:2000,protein:100,carbs:250,fat:70},generation:0,sourceRevision:1,consentRevision:0,timeZone:'Europe/Berlin'};
 await setDoc(source('alice','alice','goals','current'),goal);await assertSucceeds(getDoc(source('bob','alice','goals','current')));
 await assertFails(setDoc(source('bob','alice','contributions','forged'),await data('contributions')));await assertFails(mealQuery('eve'));
});
test('ignored legacy toggles and pauses on accepted connections',async()=>{
 await connect();await env.withSecurityRulesDisabled(async(ctx)=>{await updateDoc(doc(ctx.firestore(),'partnerConnections',id),{'settings.alice.meals':false,'settings.alice.summaries':false,'settings.alice.goals':false,'settings.alice.paused':true});});
 await setDoc(source('alice'),await data());await assertSucceeds(getDoc(source('bob')));
 await setDoc(source('alice','alice','contributions'),await data('contributions'));await assertSucceeds(mealQuery('bob','contributions'));
 await assertFails(updateDoc(conn(),{'settings.alice.meals':true}));await assertFails(updateDoc(conn(),{'settings.alice.mealGeneration':100}));
 await assertSucceeds(updateDoc(conn(),{'settings.alice.mealTimeZone':'Europe/Berlin'}));
});
test('replayed records from an older permission generation without editing the diary',async()=>{
 await connect();await setDoc(source('alice'),await data());const old=(await getDoc(source('alice'))).data();
 await env.withSecurityRulesDisabled(async(ctx)=>{await updateDoc(doc(ctx.firestore(),'partnerConnections',id),{'settings.alice.mealGeneration':1,'settings.alice.meals':false});});
 await assertSucceeds(setDoc(source('alice'),{...old,generation:1}));
 await assertSucceeds(getDoc(source('bob')));
 await assertFails(setDoc(source('alice'),{...old,generation:1}));
});
test('required bounded queries and generation filtering',async()=>{
 await connect();await setDoc(source('alice'),await data());assert.equal((await mealQuery()).size,1);
 const meals=collection(db('bob'),`partnerConnections/${id}/members/alice/meals`);
 await assertFails(getDocs(query(meals,limit(20))));await assertFails(getDocs(query(meals,where('generation','==',0),where('deletedAt','==',null))));
 await assertSucceeds(getDocs(query(collection(db('bob'),'partnerConnections'),where('participants','array-contains','bob'),limit(20))));await assertFails(getDocs(query(collection(db('eve'),'partnerConnections'),limit(20))));
});
test('rejected invalid nutrition, private metadata and mixed payloads',async()=>{
 await connect();for(const patch of[{snapshot:{...snapshot,private:'secret'}},{snapshot:{...snapshot,items:[{...snapshot.items[0],sourceFoodId:'secret'}]}},{snapshot:{...snapshot,items:[snapshot.items[0],snapshot.items[0]]}},{snapshot:{...snapshot,items:[{...snapshot.items[0],calories:-1}]}}])await assertFails(setDoc(source('alice'),await data('meals',patch)));
 await assertFails(setDoc(source('alice','alice','contributions'),await data('contributions',{snapshot})));
});
test('prevented resurrection after source deletion',async()=>{
 await connect();await setDoc(source('alice'),await data());const old=(await getDoc(source('alice'))).data();
 await setDoc(source('alice'),{deletedAt:serverTimestamp(),sourceRevision:2});assert.equal((await mealQuery()).size,0);
 await assertFails(setDoc(source('alice'),{...old,sourceRevision:3,changedAt:Timestamp.now()}));await assertFails(deleteDoc(source('alice')));
});
test('disconnect ended access in both directions',async()=>{
 await connect();await setDoc(source('alice'),await data());await updateDoc(conn('bob'),{status:'revoked',revokedAt:serverTimestamp()});
 await assertFails(mealQuery());await assertFails(getDoc(source('bob')));await assertFails(updateDoc(conn(),{status:'accepted',revokedAt:null}));
 await assertFails(setDoc(source('alice','alice','meals','new'),await data()));
 await setDoc(source('alice'),{deletedAt:serverTimestamp(),sourceRevision:2});await assertFails(setDoc(source('bob'),{deletedAt:serverTimestamp(),sourceRevision:3}));
});
