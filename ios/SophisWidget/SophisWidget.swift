import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            caloriesRemaining: 1500,
            caloriesGoal: 2500,
            protein: 80, proteinGoal: 150,
            carbs: 120, carbsGoal: 200,
            fat: 50, fatGoal: 70,
            water: 1200, waterGoal: 2500
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(
            date: Date(),
            caloriesRemaining: 1500,
            caloriesGoal: 2500,
            protein: 80, proteinGoal: 150,
            carbs: 120, carbsGoal: 200,
            fat: 50, fatGoal: 70,
            water: 1200, waterGoal: 2500
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.sophis.sophis")
        
        let caloriesRemaining = userDefaults?.double(forKey: "calories_remaining") ?? 0.0
        let caloriesGoal = userDefaults?.double(forKey: "calories_goal") ?? 2000.0
        
        let protein = userDefaults?.double(forKey: "protein_eaten") ?? 0.0
        let proteinGoal = userDefaults?.double(forKey: "protein_goal") ?? 150.0
        
        let carbs = userDefaults?.double(forKey: "carbs_eaten") ?? 0.0
        let carbsGoal = userDefaults?.double(forKey: "carbs_goal") ?? 200.0
        
        let fat = userDefaults?.double(forKey: "fat_eaten") ?? 0.0
        let fatGoal = userDefaults?.double(forKey: "fat_goal") ?? 60.0
        
        let water = userDefaults?.double(forKey: "water_ml") ?? 0.0
        let waterGoal = userDefaults?.double(forKey: "water_goal") ?? 2500.0
        
        let entry = SimpleEntry(
            date: Date(),
            caloriesRemaining: caloriesRemaining,
            caloriesGoal: caloriesGoal,
            protein: protein,
            proteinGoal: proteinGoal,
            carbs: carbs,
            carbsGoal: carbsGoal,
            fat: fat,
            fatGoal: fatGoal,
            water: water,
            waterGoal: waterGoal
        )

        // Refresh every 30 minutes to balance data freshness with battery life
        // The app triggers immediate updates via HomeWidget.updateWidget() when data changes
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60)))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let caloriesRemaining: Double
    let caloriesGoal: Double
    
    let protein: Double
    let proteinGoal: Double
    
    let carbs: Double
    let carbsGoal: Double
    
    let fat: Double
    let fatGoal: Double
    
    let water: Double
    let waterGoal: Double
    
    var progress: Double {
        guard caloriesGoal > 0 else { return 0 }
        let eaten = caloriesGoal - caloriesRemaining
        return min(max(eaten / caloriesGoal, 0), 1)
    }
}

struct CircularProgressView: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: 10)
            
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

struct MacroProgressBar: View {
    let label: String
    let value: Int
    let goal: Int
    let color: Color
    let unit: String
    
    var progress: CGFloat {
        guard goal > 0 else { return 0 }
        return min(CGFloat(Double(value) / Double(goal)), 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(value)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.primary)
                + Text("/\(goal)\(unit)")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.15))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(color)
                        .frame(width: geometry.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

struct SophisWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    
    // Theme Colors
    let accentColor = Color(red: 0.39, green: 0.40, blue: 0.95) // Indigo
    let proteinColor = Color(red: 0.02, green: 0.59, blue: 0.41) // Emerald
    let carbsColor = Color(red: 0.85, green: 0.47, blue: 0.02) // Amber
    let fatColor = Color(red: 0.88, green: 0.11, blue: 0.28) // Rose
    let waterColor = Color(red: 0.03, green: 0.57, blue: 0.70) // Cyan
    
    var body: some View {
        Group {
            if family == .systemSmall {
                // SMALL WIDGET
                VStack(spacing: 8) {
                    Spacer() // Push content down to center the ring better visually
                    
                    ZStack {
                        CircularProgressView(progress: entry.progress, color: accentColor)
                        
                        VStack(spacing: 0) {
                            Text("\(Int(entry.caloriesRemaining))")
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundColor(accentColor)
                            Text("left")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 72, height: 72)
                    
                    Spacer() // Even spacing
                    
                    HStack(spacing: 4) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 8))
                            .foregroundColor(waterColor)
                        Text("\(Int(entry.water)) ml")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(waterColor)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(waterColor.opacity(0.1))
                    .cornerRadius(8)
                    
                    Spacer() // Bottom padding
                }
                .padding(.vertical, 8)
            } else {
                // MEDIUM WIDGET
                GeometryReader { geometry in
                    let outerPadding: CGFloat = 16
                    let internalSpacing: CGFloat = 16
                    // Available width for the actual content boxes
                    let availableWidth = geometry.size.width - (outerPadding * 2) - internalSpacing
                    
                    let box1Width = availableWidth * 0.33
                    let box2Width = availableWidth * 0.67
                    
                    HStack(spacing: internalSpacing) {
                        // BOX 1 (1/3): Ring
                        ZStack {
                            CircularProgressView(progress: entry.progress, color: accentColor)
                            
                            VStack(spacing: 0) {
                                Text("\(Int(entry.caloriesRemaining))")
                                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                                    .foregroundColor(accentColor)
                                    .minimumScaleFactor(0.8)
                                Text("kcal left")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: box1Width, height: geometry.size.height)
                        
                        // BOX 2 (2/3): Bars
                        VStack(spacing: 8) {
                            MacroProgressBar(
                                label: "Protein",
                                value: Int(entry.protein),
                                goal: Int(entry.proteinGoal),
                                color: proteinColor,
                                unit: "g"
                            )
                            MacroProgressBar(
                                label: "Carbs",
                                value: Int(entry.carbs),
                                goal: Int(entry.carbsGoal),
                                color: carbsColor,
                                unit: "g"
                            )
                            MacroProgressBar(
                                label: "Fat",
                                value: Int(entry.fat),
                                goal: Int(entry.fatGoal),
                                color: fatColor,
                                unit: "g"
                            )
                            
                            // Water Bar
                            MacroProgressBar(
                                label: "Water",
                                value: Int(entry.water),
                                goal: Int(entry.waterGoal),
                                color: waterColor,
                                unit: "ml"
                            )
                        }
                        .frame(width: box2Width)
                        .frame(maxHeight: .infinity) // Center vertically
                    }
                    .padding(.horizontal, outerPadding)
                }
            }
        }
        .containerBackground(for: .widget) {
            Color(UIColor.systemBackground)
        }
    }
}

struct SophisWidget: Widget {
    let kind: String = "SophisWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            SophisWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Sophis Tracker")
        .description("Track your nutrition goals.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
