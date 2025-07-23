# 📚 Words - English Learning App

A powerful and intuitive Flutter application designed to help users learn English vocabulary through organized word packages, interactive testing, and comprehensive study features.

## 🌟 Features

### 📦 Package Management
- **Create Custom Word Packages**: Organize vocabulary by topics, difficulty levels, or any custom categorization
- **Package Statistics**: Track progress with word counts and learning statistics
- **Easy Navigation**: Intuitive interface for managing multiple vocabulary sets

### 📝 Word Management  
- **Add New Words**: Simple interface to add English words with Turkish translations
- **Rich Word Details**: Include descriptions, example sentences, and images for better learning
- **Image Support**: Upload and attach images to words for visual learning
- **Edit & Update**: Modify existing words and their details anytime

### 🎯 Learning & Testing Modes
- **Practice Mode**: Review words in a comfortable study environment
- **Test Yourself**: Interactive quizzes to test your knowledge
- **Multiple Display Modes**: Switch between English→Turkish and Turkish→English views
- **Sorting Options**: Alphabetical, newest first, or random order

### 🔍 Advanced Features
- **Smart Search**: Find words quickly across all packages
- **Word Detail Cards**: Tap any word to see comprehensive details including:
  - English word and Turkish meaning
  - Detailed descriptions
  - Example sentences  
  - Associated images
  - Date added
- **Full-Screen Image Viewer**: View word images in detail with zoom capabilities

### 💾 Data Protection & Backup
- **Multi-Location Backup**: Automatic backups to multiple locations
- **SharedPreferences Backup**: Critical data backup for extra safety
- **Auto-Restore**: Intelligent data recovery system
- **Manual Restore**: User-controlled data restoration options
- **Data Persistence**: Your data survives app cache clears and reinstalls

### 🎨 User Experience
- **Dark Theme**: Easy on the eyes with a sleek dark interface
- **Responsive Design**: Works perfectly on different screen sizes
- **Smooth Animations**: Polished UI with fluid transitions
- **Accessibility**: Designed with user accessibility in mind

## 🛠️ Technical Stack

- **Framework**: Flutter (Dart)
- **Database**: SQLite with sqflite package
- **Local Storage**: SharedPreferences for backup data
- **Image Handling**: image_picker package
- **UI Components**: Material Design 3
- **Typography**: Google Fonts (Inter)
- **State Management**: StatefulWidget with proper lifecycle management

## 📱 Screenshots

### Main Features
- Package listing with statistics
- Word management interface
- Interactive test modes
- Detailed word cards

### UI Highlights
- Modern dark theme
- Intuitive navigation
- Rich typography
- Smooth animations

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (≥3.2.6)
- Dart SDK
- Android Studio / VS Code
- Android device or emulator

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/words-learning-app.git
   cd words-learning-app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Building APK

```bash
# Build release APK
flutter build apk --release

# Build app bundle (recommended for Play Store)
flutter build appbundle --release
```

## 📦 Dependencies

### Core Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  sqflite: ^2.3.0              # Local database
  path_provider: ^2.1.0        # File system paths
  shared_preferences: ^2.2.2   # Simple data storage
  image_picker: ^1.0.7         # Image selection
  google_fonts: ^4.0.0         # Typography
  path: ^1.8.3                 # Path manipulation
```

### Development Dependencies
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0
  flutter_launcher_icons: ^0.13.1
```

## 🏗️ Project Structure

```
lib/
├── database/
│   └── database_helper.dart     # SQLite database management
├── models/
│   ├── package.dart             # Package data model
│   └── word.dart                # Word data model
├── pages/
│   ├── packages_page.dart       # Main package listing
│   ├── add_word_page.dart       # Add new words
│   ├── view_list_page.dart      # View word lists
│   ├── practice_page.dart       # Practice mode
│   ├── test_yourself_page.dart  # Test mode
│   └── ...                     # Other pages
├── widgets/
│   └── add_package_dialog.dart  # Custom widgets
└── main.dart                    # App entry point
```

## 💾 Database Schema

### Packages Table
```sql
CREATE TABLE packages(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  createdAt INTEGER NOT NULL,
  wordCount INTEGER DEFAULT 0
)
```

### Words Table
```sql
CREATE TABLE words(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  packageId INTEGER NOT NULL,
  englishWord TEXT NOT NULL,
  turkishMeaning TEXT NOT NULL,
  description TEXT,
  imagePath TEXT,
  exampleSentence TEXT,
  createdAt INTEGER NOT NULL,
  isLearned INTEGER DEFAULT 0,
  FOREIGN KEY (packageId) REFERENCES packages (id) ON DELETE CASCADE
)
```

## 🔧 Key Features Implementation

### Data Persistence
- **Multiple Backup Locations**: Internal storage, external storage, SharedPreferences
- **Auto-Recovery**: Automatic data restoration on app startup
- **Integrity Checks**: Database validation and corruption detection

### Image Handling
- **Local Storage**: Images stored in device storage with proper path management
- **Fallback Handling**: Graceful handling of missing or corrupted images
- **Memory Optimization**: Efficient image loading and display

### Search & Filter
- **Real-time Search**: Instant filtering as user types
- **Multi-field Search**: Search across English words and Turkish meanings
- **Sort Options**: Multiple sorting algorithms for different use cases

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Guidelines
1. Follow Flutter best practices
2. Maintain code consistency
3. Add comments for complex logic
4. Test thoroughly before submitting
5. Update documentation as needed

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Material Design for UI guidelines
- Google Fonts for beautiful typography
- SQLite for reliable local storage

## 📞 Support

If you have any questions or run into issues, please open an issue on GitHub or contact the maintainer.

---

**Made with ❤️ using Flutter**

*Happy Learning! 🎓*
