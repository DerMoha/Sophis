# Sophis - Phased Implementation Plan

Rebuilding a clean, minimalistic calorie/nutrition tracking app (formerly Fitcal) from scratch.

---

## Phase Overview

| Phase | Focus | Deliverable |
|-------|-------|-------------|
| **1** | Foundation | Theme, models, navigation |
| **2** | Core Features | Food logging, water, weight, recipes |
| **3** | AI Integration | Tiered AI (Basic → Pro → Cloud) |
| **4** | Polish | Activity graph, animations |

---

## Phase 1: Foundation 🏗️

**Deliverables:**
- Flutter project setup
- Multilingual (EN/DE) with device detection
- Minimalistic theme (light/dark)
- 8 data models
- Storage service
- Basic home + settings screens

**Dependencies:** `flutter_localizations`, `intl`, `provider`, `shared_preferences`

---

## Phase 2: Core Features 📊

**Deliverables:**
- NutritionProvider (state management)
- Goals setup (all optional)
- Calorie calculator (TDEE)
- Manual food entry
- Food search (OpenFoodFacts)
- Barcode scanner
- Water tracking
- Weight tracker with chart
- Recipes

**Dependencies:** `fl_chart`, `mobile_scanner`, `http`

---

## Phase 3: AI Integration 🤖

### AI Tiers

| Tier | Name | Size | Description |
|------|------|------|-------------|
| 🔒 | Offline Basic | ~15MB | TFLite Food101 (101 foods) |
| 🔒+ | Offline Pro | ~300MB | + Gemma 3 Nano (smart descriptions) |
| ☁️ | Cloud | 0MB | Gemini (multi-image, most accurate) |

**Phase 3a:** TFLite classifier
**Phase 3b:** Gemma local LLM (optional)  
**Phase 3c:** Gemini cloud API

**Dependencies:** `image_picker`, `tflite_flutter`, `flutter_gemma`, `google_generative_ai`

---

## Phase 4: Polish ✨

**Deliverables:**
- GitHub-style activity graph (🔴🟡🟢)
- Streak counter
- Smooth animations
- Final testing

---

## Design System

| Aspect | Specification |
|--------|---------------|
| Colors | Monochrome + blue accent (#3B82F6) |
| Cards | Flat, 1px border, no shadows |
| Progress | Horizontal bars |
| Typography | System font, 2-3 weights |

---

## Verification

Each phase produces a buildable, testable app:

```bash
cd c:\Users\Moha\Sophis
flutter analyze
flutter run
```
