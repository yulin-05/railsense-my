# RailSense MY

**Know Before You Go — Avoid the Crowd, Travel Smarter on Malaysia's Rail Network**

RailSense MY is a Flutter mobile application that helps Malaysian commuters explore railway information, understand ridership patterns, estimate crowd levels, and plan smarter rail journeys using Malaysia Government Open Data.

## Main Features

### 1. User & Personalization
- User registration and login
- Forgot password
- Profile management
- Favourite routes
- Application settings and appearance

### 2. Smart Commute Dashboard & AI Rail Assistant
- Latest railway passenger volume
- Ridership trend
- Estimated crowd level and capacity
- Suggested off-peak travel period
- Railway selection
- Government data updates
- Quick access to application features
- Google Gemini-powered RailSense AI Assistant

### 3. Railway Explorer
- Railway information
- Route search
- Route details
- Popular routes
- Station information and facilities

### 4. Insights
- Weekly and monthly ridership trends
- Railway usage comparison
- Top railway usage
- Railway usage insights

## Technologies Used

- Flutter
- Dart
- Supabase
- Google Gemini
- REST API / HTTP
- Malaysia Government Open Data
- Git & GitHub

## Data Source

RailSense MY uses Malaysia Government Open Data railway datasets to provide railway ridership information and travel insights.

The application uses available railway ridership data to calculate estimated crowd levels and recommend suitable off-peak travel periods.

> Crowd levels and estimated capacity are based on available Government Open Data and are not real-time train occupancy readings.

## AI Rail Assistant

RailSense MY includes an AI-powered railway assistant using Google Gemini.

The assistant provides railway-related travel guidance and is designed to avoid false real-time crowd claims, fabricated passenger numbers, and unavailable railway information.

## How to Run RailSense MY

### Requirements

Before running the project, please make sure the following are available:

- Flutter SDK
- Android Studio
- Android Emulator or physical Android device
- Internet connection

### Step 1 — Open the Project

Extract the submitted RailSense MY Flutter project and open the project folder in Android Studio.

### Step 2 — Install Dependencies

Open the Terminal in Android Studio and run:

```bash
flutter pub get
```

### Step 3 — Start the Application

Start an Android Emulator or connect a physical Android device.

Then run:

```bash
flutter run --dart-define=GEMINI_API_KEY=AQ.Ab8RN6Iyya_MIVb_Y1If3fbD3je_Keb6Z9uc4BVG79Q-X92lYw

```

The application will launch with the Google Gemini-powered RailSense AI Assistant enabled.

> An Internet connection is required to retrieve Malaysia Government Open Data and generate Google Gemini AI responses.

## Team Members

| Team Member | Student ID | Module / Contribution |
|-------------|------------|-----------------------|
| Woon Zi Xuan | 25JMR10226 | Smart Commute Dashboard, AI Rail Assistant, Government Open Data Integration & Final System Integration        |
| Tan Bee Xuan | 25JMR10221 | User & Personalization |
| Tay Yu Lin   | 25JMR10223 | Railway Explorer       |
| Tee Xin Yuin | 25JMR10224 | Insights               |

## Project Information

- **Course:** BMIT2073 Mobile Application Development
- **Project:** RailSense MY
- **Group:** 4G
- **Platform:** Flutter Mobile Application

## Disclaimer

RailSense MY is developed for academic purposes.

Railway ridership information is derived from available Malaysia Government Open Data. Crowd levels, estimated capacity, and suggested travel periods are analytical estimates and should not be interpreted as real-time train occupancy or official railway operational information.
