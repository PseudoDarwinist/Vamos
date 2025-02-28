# Bloom - Conversational Expense Tracker

Bloom is a user-friendly expense tracking app with a nature-inspired UI that uses natural language processing to scan receipts, extract information, and present your financial data in an intuitive way.

## Features

- **Invoice Scanning & Processing**: OCR functionality to extract text from physical receipts and digital invoices
- **Conversational Interface**: Natural language summaries of spending and ability to ask questions about your spending
- **Expense Management**: Categorization of spending with monthly and historical views
- **Nature-Inspired UI**: Organic visual elements with soothing color palette and growth metaphors

## Project Structure

```
Bloom/
├── App/
│   ├── BloomApp.swift          # Main app entry point
│   └── AppDelegate.swift       # App delegate for handling lifecycle events
├── Assets/
│   ├── Assets.xcassets         # Images and app icons
│   └── Colors.xcassets         # Color assets
├── Models/
│   ├── Transaction.swift       # Transaction data model
│   ├── Category.swift          # Category data model
│   └── MonthSummary.swift      # Monthly summary data model
├── Views/
│   ├── Core/
│   │   ├── HeaderComponent.swift      # Header with logo and monthly summary
│   │   ├── SpendingStoryCard.swift    # Card showing narrative summary
│   │   ├── TransactionItem.swift      # Individual transaction display
│   │   └── CameraButton.swift         # Camera button for scanning receipts
│   ├── Screens/
│   │   ├── HomeView.swift             # Main home screen
│   │   ├── CategoriesView.swift       # Categories screen (not implemented yet)
│   │   ├── ScannerView.swift          # Scanner screen (not implemented yet)
│   │   ├── HistoryView.swift          # History screen (not implemented yet)
│   │   └── SettingsView.swift         # Settings screen (not implemented yet)
│   └── Navigation/
│       └── TabBarView.swift           # Bottom tab navigation
├── Services/
│   ├── OCRService.swift         # OCR functionality for receipt scanning
│   ├── NLPService.swift         # NLP processing (not implemented yet)
│   └── GeminiService.swift      # Integration with Google Gemini API
├── Utilities/
│   ├── Extensions/
│   │   ├── Color+Extensions.swift     # Color utility extensions
│   │   └── Date+Extensions.swift      # Date utility extensions
│   └── Constants.swift                # App-wide constants
└── Resources/
    └── Info.plist                     # App configuration
```

## Getting Started

1. Clone this repository
2. Open the project in Xcode
3. Set up your Google Gemini API key in Constants.swift (already included)
4. Build and run the app on your iOS device or simulator

## API Integration

Bloom uses Google's Gemini API for natural language processing capabilities:

- **Gemini 2.0 Flash**: Primary API for high-quality NLP processing
- **Gemini 2.0 Flash-Lite**: Fallback API when rate limits are reached

## Design Details

### Colors
- Primary Green: #2E8B57 (Sea Green)
- Secondary Green: #3CB371 (Medium Sea Green)
- Background: #F0F8F5 (Mint Cream)
- Accents: #66CDAA (Medium Aquamarine)
- Text Primary: #2F4F4F (Dark Slate Gray)
- Text Secondary: #5F9EA0 (Cadet Blue)

### Typography
- SF Pro Display Rounded for headings
- SF Pro Text for body content

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgements

- Google Gemini API for natural language processing
- Vision framework for OCR processing