# EcoScrap (ஈகோஸ்க்ராப் / इकोस्क्रैप)
## AI-Powered Formalization Platform for Informal E-Waste Collectors
> **Hackathon Challenge:** Challenge 19 – Digital Platform for Formal E-Waste Collection and Recycling  
> **Tagline:** *Identify. Value. Bid. Trace. Recycle. — From Informal Scrap to Formal Circularity.*

---

## 🌟 Key Highlights & Innovations (Strictly Zero AWS)

1. **Cross-Platform Flutter Frontend (Android + Web/Desktop):**
   - **Offline-First & In-Memory Store:** Instant reactive UI updates with persistent disk outbox (`SharedPreferences`) allowing collectors to draft lots, inspect prices, and queue collections without active internet.
   - **Vernacular Multilingual Support:** One-tap toggle between **English**, **Tamil (தமிழ்)**, and **Hindi (हिंदी)**.
   - **Voice-First Assistant:** Simulated voice intent parser turning natural language commands (*"I have 2 old laptops and 5kg copper cables"*) into structured digital lots.
   - **Collector Trust Card:** Credibility badge (Trust Score: 94.5/100, 182 collections formalized) empowering informal collectors.

2. **AI Lens (Material Classification & Safety Advisor):**
   - 3-tier classification hierarchy (**Category -> Item Type -> Grade**).
   - High-grade PCB vs Low-grade PCB vs Lithium-ion vs Copper wiring recognition with confidence ratings.
   - **Critical Hazard Shield:** Automatic detection of thermal runaway, acid leakage, and puncture risks on batteries with safety handling protocols.

3. **AI Fair Value & Price Anomaly Shield:**
   - Real-time algorithmic estimation of fair market price ranges (min/max in INR) with an **explainable breakdown** of metal recovery indices, grade bonuses, and logistics margins.
   - **Price Anomaly Detector (Exploitation Shield):** Statistical IQR engine that flags predatory lowball bids (< 25% below fair floor) to protect informal collectors from middleman exploitation.

4. **Recycler Marketplace & Smart Matchmaker:**
   - Reverse bidding mechanism allowing CPCB-authorized recyclers to compete transparently.
   - Multi-factor recommendation algorithm scoring offers on Price (40%), Distance (25%), Recycler Reliability (20%), and Material Specialization (15%).

5. **Traceable QR E-Waste Passport & Tamper-Evident Ledger:**
   - Unique QR code generated for every lot.
   - **Cryptographic SHA-256 Hash Chain:** Every state transition (`LOT_CREATED`, `BID_ACCEPTED`, `SCALE_VERIFIED_AND_HANDOVER`) is cryptographically sealed to its prior block hash.
   - Public passport viewer verifying 100% tamper-free chain of custody, circular material recovery yields, and avoided CO2e emissions.

6. **Self-Hosted PostgreSQL Relational Engine:**
   - Strict relational schema for users, collectors, recyclers, lots, bids, handover events, risk alerts, and cryptographic blocks.
   - Complete zero-cloud/zero-AWS design (local storage, open-source models, self-contained Docker Compose).

---

## 🏗️ System Architecture

```
┌────────────────────────────────────────────────────────────┐
│                    FLUTTER CROSS-PLATFORM                  │
│  Collector App (Mobile) | Recycler Portal | QR Passport    │
│            │                             │                 │
│            ▼                             ▼                 │
│     [In-Memory State]            [Persistent Outbox]       │
└────────────────────────────┬───────────────────────────────┘
                             │ REST API (JSON)
                             ▼
┌────────────────────────────────────────────────────────────┐
│                 FASTAPI BACKEND GATEWAY                    │
│  • AI Lens & Hazard Classifier                             │
│  • Fair Value & Anomaly Detector                           │
│  • Reverse Bidding & Smart Matchmaker                      │
│  • Scale Handover & OTP Verification                       │
│  • Cryptographic SHA-256 Event Chain                       │
│  • QR Passport Generator & Circularity Analytics           │
└────────────────────────────┬───────────────────────────────┘
                             │
                             ▼
┌────────────────────────────────────────────────────────────┐
│                  PERSISTENCE (ZERO AWS)                    │
│  • PostgreSQL 16 (docker-compose.yml)                      │
│  • Resilient local fallback engine                         │
│  • Local media storage (`/media/qr`, `/media/lots`)        │
└────────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start Guide

### 1. Start Database (Optional Docker PostgreSQL)
```bash
docker compose up -d
```
*(If Docker is not running, the backend automatically uses a local persistent SQLite database without crashing!)*

### 2. Run Backend (FastAPI)
```bash
# In project root:
python -m uvicorn backend.app.main:app --host 0.0.0.0 --port 8000 --reload
```
Interactive Swagger API docs available at: **http://127.0.0.1:8000/docs**

### 3. Run Frontend (Flutter)
```bash
cd frontend

# Run on Web (Chrome):
flutter run -d chrome

# Or run on Windows Desktop:
flutter run -d windows

# Or run on Android Emulator/Device:
flutter run -d android
```

---

## 🧪 Running Automated Tests

### Backend Comprehensive Test Suite (Pytest - 28/28 Tests Passed ✅)
Verifies database models, 3-tier AI Lens, fair value engine, reverse bidding, anomaly detector, smart matchmaker, dual-weight scale verification, SHA-256 tamper-evident blockchain ledger, vernacular voice parser (EN/TA/HI), Safety AI SOPs, and circularity metrics:
```bash
python -m pytest backend/tests/test_phase1_foundation.py backend/tests/test_phase2_collector_ai.py backend/tests/test_phase3_marketplace_bids.py backend/tests/test_phase4_handover_passport.py backend/tests/test_phase5_vernacular_safety_analytics.py -v
```

### Frontend Test Suite (Flutter Test - 4/4 Tests Passed ✅)
Verifies multi-role tab navigation, in-memory state initialization, offline disk outbox, and network auto-sync:
```bash
cd frontend
flutter test
```

### Frontend Static Analysis (0 Issues Found ✅)
```bash
cd frontend
flutter analyze lib/
```

---

## 📱 Signature End-to-End Walkthrough Flow

1. **Collector EcoScrap Tab:**
   - Switch language to **தமிழ்**, **हिंदी**, or **English**.
   - Tap **"Speak (Voice Assistant)"** -> select or speak *"10 கிலோ தாமிர கம்பி"* or *"5 किलो पुराना लैपटॉप मदरबोर्ड"*.
   - View vernacular AI Lens confidence (92%+), extracted weight, item grade, and instant safety warnings.
   - Tap **"Safety Protocols (SOP)"** to view CPCB-aligned handling guidelines (sand bucket containment, PVC anti-burning rules) in Tamil/Hindi/English.
   - Observe **Fair Market Value Range** with "Why this price?" explainability factors.
   - Toggle **Offline Switch**: create lot while offline, observe instant outbox badge, toggle online, tap **"Sync Now"** to watch it sync to central EcoScrap with temporary-to-canonical ID swap.

2. **Recycler Hub Tab:**
   - Browse open lots with material filters.
   - Submit a competitive bid vs. a predatory lowball bid (e.g. ₹2,000 for a ₹5,000 lot).
   - Witness the **Price Anomaly Alert (Exploitation Shield)** triggered immediately with statistical justification!
   - Under Handover Station, enter OTP and calibrated scale reading to verify dual-weight tolerance.

3. **QR Passport Tab:**
   - Enter lot code (e.g., `EW-TN-2026-000184`).
   - Observe **Cryptographic Ledger Integrity: 100% Tamper-Free**.
   - Inspect the block chain with previous hash and current SHA-256 block hash.
   - View circular material yield breakdown (Copper, Aluminum, Polymers) and avoided CO2e emissions.

4. **Governance & Admin KPIs Tab:**
   - Live ecosystem KPIs: total e-waste formalized, CO2e avoided ($1.44 \text{ kg/kg}$), toxic heavy metals contained ($25 \text{ g/kg}$), landfill space saved, equivalent trees offset.
   - Material distribution breakdown and live predatory anomaly radar.
