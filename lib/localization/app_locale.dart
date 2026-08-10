import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const appTranslations = <String, Map<String, String>>{
  'Student': {'si': 'ශිෂ්‍යයා', 'ta': 'மாணவர்'},
  'Teacher': {'si': 'ගුරුවරයා', 'ta': 'ஆசிரியர்'},
  'Dashboard': {'si': 'මුල් පිටුව', 'ta': 'முகப்பு'},
  'Reception': {'si': 'පිළිගැනීම', 'ta': 'வரவேற்பு'},
  'My ICT Space': {'si': 'මගේ ICT අවකාශය', 'ta': 'எனது ICT இடம்'},
  'Classes & batches': {
    'si': 'පන්ති සහ කණ්ඩායම්',
    'ta': 'வகுப்புகள் மற்றும் குழுக்கள்'
  },
  'Manage Learning Space': {
    'si': 'ICT අවකාශ කළමනාකරණය',
    'ta': 'ICT இடங்களை நிர்வகி'
  },
  'Students': {'si': 'ශිෂ්‍යයන්', 'ta': 'மாணவர்கள்'},
  'Attendance': {'si': 'පැමිණීම', 'ta': 'வருகை'},
  'QR quick attendance': {'si': 'QR ඉක්මන් පැමිණීම', 'ta': 'QR விரைவு வருகை'},
  'Assignments & quizzes': {
    'si': 'පැවරුම් සහ ප්‍රශ්නාවලි',
    'ta': 'பணிகள் மற்றும் வினாடி வினா'
  },
  'Assignments': {'si': 'පැවරුම්', 'ta': 'பணிகள்'},
  'Messages': {'si': 'පණිවිඩ', 'ta': 'செய்திகள்'},
  'Curriculum': {'si': 'විෂය නිර්දේශය', 'ta': 'பாடத்திட்டம்'},
  'Progress & Grades': {
    'si': 'ප්‍රගතිය සහ ලකුණු',
    'ta': 'முன்னேற்றம் மற்றும் மதிப்பெண்கள்'
  },
  'Reports': {'si': 'වාර්තා', 'ta': 'அறிக்கைகள்'},
  'Calendar': {'si': 'දින දර්ශනය', 'ta': 'நாட்காட்டி'},
  'Quotes & notices': {
    'si': 'උපුටා දැක්වීම් සහ දැන්වීම්',
    'ta': 'மேற்கோள்கள் மற்றும் அறிவிப்புகள்'
  },
  'Institute workspace': {'si': 'ආයතන අවකාශය', 'ta': 'நிறுவன பணியிடம்'},
  'Notifications': {'si': 'දැනුම්දීම්', 'ta': 'அறிவிப்புகள்'},
  'My profile': {'si': 'මගේ පැතිකඩ', 'ta': 'என் சுயவிவரம்'},
  'My Profile': {'si': 'මගේ පැතිකඩ', 'ta': 'என் சுயவிவரம்'},
  'Settings': {'si': 'සැකසුම්', 'ta': 'அமைப்புகள்'},
  'Change class': {'si': 'පන්තිය මාරු කරන්න', 'ta': 'வகுப்பை மாற்று'},
  'Refresh': {'si': 'යාවත්කාලීන කරන්න', 'ta': 'புதுப்பி'},
  'Refresh from server': {
    'si': 'සේවාදායකයෙන් යාවත්කාලීන කරන්න',
    'ta': 'சேவையகத்திலிருந்து புதுப்பி'
  },
  'Appearance': {'si': 'පෙනුම', 'ta': 'தோற்றம்'},
  'Colour theme': {'si': 'වර්ණ තේමාව', 'ta': 'வண்ண தீம்'},
  'Device theme': {'si': 'උපාංග තේමාව', 'ta': 'சாதன தீம்'},
  'Light theme': {'si': 'ආලෝක තේමාව', 'ta': 'ஒளி தீம்'},
  'Dark theme': {'si': 'අඳුරු තේමාව', 'ta': 'இருள் தீம்'},
  'Sign out': {'si': 'පිටවන්න', 'ta': 'வெளியேறு'},
  'Security': {'si': 'ආරක්ෂාව', 'ta': 'பாதுகாப்பு'},
  'Learning inbox': {'si': 'ඉගෙනුම් දැනුම්දීම්', 'ta': 'கற்றல் அறிவிப்புகள்'},
  'English': {'si': 'ඉංග්‍රීසි', 'ta': 'ஆங்கிலம்'},
  'Sinhala': {'si': 'සිංහල', 'ta': 'சிங்களம்'},
  'Tamil': {'si': 'දෙමළ', 'ta': 'தமிழ்'},
  'Student space': {'si': 'ශිෂ්‍ය අවකාශය', 'ta': 'மாணவர் இடம்'},
  'My Learning Calendar': {
    'si': 'මගේ ඉගෙනුම් දින දර්ශනය',
    'ta': 'எனது கற்றல் நாட்காட்டி'
  },
  'Curriculum Library': {
    'si': 'විෂය නිර්දේශ පුස්තකාලය',
    'ta': 'பாடத்திட்ட நூலகம்'
  },
  'Progress & Results': {
    'si': 'ප්‍රගතිය සහ ප්‍රතිඵල',
    'ta': 'முன்னேற்றம் மற்றும் முடிவுகள்'
  },
  'Teacher dashboard': {'si': 'ගුරු මුල් පිටුව', 'ta': 'ஆசிரியர் முகப்பு'},
  'Teacher settings': {'si': 'ගුරු සැකසුම්', 'ta': 'ஆசிரியர் அமைப்புகள்'},
  'Edit teacher profile': {
    'si': 'ගුරු පැතිකඩ සංස්කරණය',
    'ta': 'ஆசிரியர் சுயவிவரத்தைத் திருத்து'
  },
  'Enter student results': {
    'si': 'ශිෂ්‍ය ප්‍රතිඵල ඇතුළත් කරන්න',
    'ta': 'மாணவர் முடிவுகளை உள்ளிடு'
  },
  'Invite teacher': {
    'si': 'ගුරුවරයෙකුට ආරාධනා කරන්න',
    'ta': 'ஆசிரியரை அழைக்கவும்'
  },
  'Payments': {'si': 'ගෙවීම්', 'ta': 'கட்டணங்கள்'},
  'Public identity and teaching details.': {
    'si': 'පොදු අනන්‍යතාව සහ ඉගැන්වීම් තොරතුරු.',
    'ta': 'பொது அடையாளம் மற்றும் கற்பித்தல் விவரங்கள்.'
  },
  'Your teacher identity, shareable URL, and device controls.': {
    'si': 'ඔබගේ ගුරු අනන්‍යතාව, බෙදාගත හැකි URL සහ උපාංග පාලන.',
    'ta':
        'உங்கள் ஆசிரியர் அடையாளம், பகிரக்கூடிய URL மற்றும் சாதனக் கட்டுப்பாடுகள்.'
  },
  'View connected institutes and respond to invitations.': {
    'si': 'සම්බන්ධිත ආයතන බලන්න සහ ආරාධනාවලට ප්‍රතිචාර දක්වන්න.',
    'ta': 'இணைக்கப்பட்ட நிறுவனங்களைப் பார்த்து அழைப்புகளுக்குப் பதிலளிக்கவும்.'
  },
  'Open tasks, deadlines, submitted files and replacement availability.': {
    'si': 'විවෘත කාර්ය, අවසන් දින, ඉදිරිපත් කළ ගොනු සහ නැවත කිරීමේ අවස්ථා.',
    'ta':
        'திறந்த பணிகள், காலக்கெடுக்கள், சமர்ப்பித்த கோப்புகள் மற்றும் மீண்டும் செய்யும் வாய்ப்புகள்.'
  },
  'Monthly totals and every attendance record from your active classes.': {
    'si': 'සක්‍රිය පන්තිවල මාසික එකතුව සහ සියලු පැමිණීමේ වාර්තා.',
    'ta':
        'செயலில் உள்ள வகுப்புகளின் மாத மொத்தங்களும் அனைத்து வருகைப் பதிவுகளும்.'
  },
  'Your private conversation with your active ICT teacher.': {
    'si': 'ඔබගේ සක්‍රිය ICT ගුරුවරයා සමඟ පෞද්ගලික සංවාදය.',
    'ta': 'செயலில் உள்ள ICT ஆசிரியருடனான உங்கள் தனிப்பட்ட உரையாடல்.'
  },
  'Marks from teacher sheets and completed quizzes.': {
    'si': 'ගුරු ලකුණු පත්‍ර සහ සම්පූර්ණ කළ ප්‍රශ්නාවලිවල ලකුණු.',
    'ta': 'ஆசிரியர் தாள்கள் மற்றும் முடித்த வினாடி வினாக்களின் மதிப்பெண்கள்.'
  },
  'Your identity, teacher accounts, student card and attendance QR.': {
    'si': 'ඔබගේ අනන්‍යතාව, ගුරු ගිණුම්, ශිෂ්‍ය කාඩ්පත සහ පැමිණීමේ QR.',
    'ta': 'உங்கள் அடையாளம், ஆசிரியர் கணக்குகள், மாணவர் அட்டை மற்றும் வருகை QR.'
  },
  'Newest messages and student access requests appear first.': {
    'si': 'නවතම පණිවිඩ සහ ශිෂ්‍ය ප්‍රවේශ ඉල්ලීම් මුලින් පෙන්වයි.',
    'ta': 'புதிய செய்திகள் மற்றும் மாணவர் அணுகல் கோரிக்கைகள் முதலில் தோன்றும்.'
  },
  'Welcome back': {
    'si': 'නැවත සාදරයෙන් පිළිගනිමු',
    'ta': 'மீண்டும் வரவேற்கிறோம்'
  },
  'Sign in': {'si': 'පුරනය වන්න', 'ta': 'உள்நுழைக'},
  'Create teacher login': {
    'si': 'ගුරු ගිණුම සාදන්න',
    'ta': 'ஆசிரியர் கணக்கை உருவாக்கவும்'
  },
  'Email address': {'si': 'විද්‍යුත් තැපැල් ලිපිනය', 'ta': 'மின்னஞ்சல் முகவரி'},
  'Password': {'si': 'මුරපදය', 'ta': 'கடவுச்சொல்'},
  'Confirm password': {
    'si': 'මුරපදය තහවුරු කරන්න',
    'ta': 'கடவுச்சொல்லை உறுதிப்படுத்தவும்'
  },
  'Full name': {'si': 'සම්පූර්ණ නම', 'ta': 'முழுப் பெயர்'},
  'Continue with Google': {
    'si': 'Google සමඟ ඉදිරියට යන්න',
    'ta': 'Google மூலம் தொடரவும்'
  },
  'Your login stays securely saved on this device.': {
    'si': 'ඔබගේ පිවිසුම මෙම උපාංගයේ ආරක්ෂිතව සුරැකේ.',
    'ta': 'உங்கள் உள்நுழைவு இந்த சாதனத்தில் பாதுகாப்பாக சேமிக்கப்படும்.'
  },
  'Already have a teacher account? Sign in': {
    'si': 'දැනටමත් ගුරු ගිණුමක් තිබේද? පුරනය වන්න',
    'ta': 'ஏற்கனவே ஆசிரியர் கணக்கு உள்ளதா? உள்நுழைக'
  },
  'New teacher? Create an account': {
    'si': 'නව ගුරුවරයෙක්ද? ගිණුමක් සාදන්න',
    'ta': 'புதிய ஆசிரியரா? கணக்கை உருவாக்கவும்'
  },
  'Create teacher account': {
    'si': 'ගුරු ගිණුම සාදන්න',
    'ta': 'ஆசிரியர் கணக்கை உருவாக்கவும்'
  },
  'Teacher verification': {
    'si': 'ගුරු සත්‍යාපනය',
    'ta': 'ஆசிரியர் சரிபார்ப்பு'
  },
  'NIC number': {
    'si': 'ජාතික හැඳුනුම්පත් අංකය',
    'ta': 'தேசிய அடையாள அட்டை எண்'
  },
  'Expected total students': {
    'si': 'අපේක්ෂිත මුළු ශිෂ්‍ය සංඛ්‍යාව',
    'ta': 'எதிர்பார்க்கப்படும் மொத்த மாணவர்கள்'
  },
  'Submit for admin approval': {
    'si': 'පරිපාලක අනුමැතිය සඳහා යවන්න',
    'ta': 'நிர்வாகி ஒப்புதலுக்கு அனுப்பவும்'
  },
  'Submitting…': {'si': 'යවමින්…', 'ta': 'அனுப்பப்படுகிறது…'},
  'Language': {'si': 'භාෂාව', 'ta': 'மொழி'},
};

class AppLocaleController extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  String _code = 'en';
  String get code => _code;
  Locale get locale => Locale(_code);

  Future<void> load() async {
    _code = await _storage.read(key: 'magical_app_language') ?? 'en';
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    if (!['en', 'si', 'ta'].contains(code) || code == _code) return;
    _code = code;
    await _storage.write(key: 'magical_app_language', value: code);
    notifyListeners();
  }

  String tr(String value) =>
      _code == 'en' ? value : appTranslations[value]?[_code] ?? value;
}

final appLocale = AppLocaleController();
