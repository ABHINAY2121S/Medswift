import '../models/auth_models.dart';
import 'auth_service.dart';

/// A matched doctor recommendation for a patient.
class DoctorRecommendation {
  final DoctorProfile doctor;
  final double starRating;   // 0.0–5.0
  final String matchReason;  // e.g. "Cardiologist — matched to your heart condition"
  final bool isTopRated;     // true if rating >= 4.0

  DoctorRecommendation({
    required this.doctor,
    required this.starRating,
    required this.matchReason,
    required this.isTopRated,
  });
}

class RecommendationService {
  // ── Speciality → diagnosis keyword map ───────────────────────────────────
  static const Map<String, List<String>> _specialityKeywords = {
    'Cardiologist': [
      'heart', 'cardiac', 'myocardial', 'infarction', 'mi', 'stemi', 'nstemi',
      'angina', 'chf', 'arrhythmia', 'atrial fibrillation', 'afib', 'coronary',
      'cad', 'palpitation', 'hypertension', 'htn', 'heart failure', 'aortic',
    ],
    'Neurologist': [
      'stroke', 'cva', 'tia', 'seizure', 'epilepsy', 'brain', 'neuro',
      'headache', 'migraine', 'parkinson', 'alzheimer', 'dementia',
      'neuropathy', 'multiple sclerosis', 'ms', 'meningitis', 'encephalitis',
    ],
    'Pulmonologist': [
      'copd', 'asthma', 'pneumonia', 'respiratory', 'ards', 'lung',
      'pulmonary', 'bronchitis', 'pleural', 'emphysema', 'fibrosis',
      'tuberculosis', 'tb', 'spo2', 'oxygen', 'breathless',
    ],
    'Nephrologist': [
      'kidney', 'renal', 'ckd', 'aki', 'dialysis', 'nephritis',
      'proteinuria', 'creatinine', 'uremia', 'glomerulo', 'acute kidney',
    ],
    'Endocrinologist': [
      'diabetes', 'diabetic', 'dka', 'hhs', 'hypoglycemia', 'hyperglycemia',
      'thyroid', 'hypothyroid', 'hyperthyroid', 'graves', 'hashimoto',
      'addison', 'adrenal', 'pituitary', 'insulin', 'hormonal',
    ],
    'Orthopedist': [
      'fracture', 'bone', 'joint', 'arthritis', 'ortho', 'spine',
      'disc', 'ligament', 'dislocation', 'osteoporosis', 'knee', 'hip',
    ],
    'General Surgeon': [
      'appendicitis', 'cholecystitis', 'gallbladder', 'hernia', 'bowel',
      'obstruction', 'perforation', 'abscess', 'surgical', 'trauma', 'polytrauma',
    ],
    'Intensivist / Critical Care': [
      'sepsis', 'septicemia', 'shock', 'multi-organ', 'icu', 'critical',
      'anaphylaxis', 'hemorrhage', 'polytrauma', 'cardiac arrest',
    ],
    'Pediatrician': [
      'child', 'infant', 'pediatric', 'neonatal', 'newborn', 'febrile',
      'kawasaki', 'rsv', 'croup',
    ],
    'Oncologist': [
      'cancer', 'tumor', 'malignant', 'carcinoma', 'lymphoma',
      'leukemia', 'chemotherapy', 'oncology', 'metastasis',
    ],
    'Psychiatrist': [
      'psychiatric', 'psychosis', 'schizophrenia', 'depression', 'bipolar',
      'overdose', 'suicidal', 'mental', 'anxiety', 'panic',
    ],
    'General Physician': [
      // General physician matches everything as a fallback
      '',
    ],
  };

  /// Compute star rating (0.0–5.0) from doctor's tracked stats.
  static double computeStarRating(DoctorProfile doctor) {
    if (doctor.totalTransfers == 0) return 0.0;
    final ratio = doctor.completedTransfers / doctor.totalTransfers;
    // Scale: completion ratio × 5, minimum 1 star if any transfers exist
    final raw = (ratio * 5.0).clamp(0.0, 5.0);
    // Round to nearest 0.5
    return (raw * 2).round() / 2;
  }

  /// Returns true if [speciality] is relevant to [diagnosis].
  static bool matchesSpeciality(String speciality, String diagnosis) {
    if (speciality.isEmpty || speciality == 'General Physician') return true;
    final keywords = _specialityKeywords[speciality] ?? [];
    final lower = diagnosis.toLowerCase();
    return keywords.any((kw) => kw.isNotEmpty && lower.contains(kw));
  }

  /// Generate a human-readable match reason string.
  static String _matchReason(String speciality, String diagnosis) {
    if (speciality.isEmpty || speciality == 'General Physician') {
      return 'General Physician — available for all conditions';
    }
    return '$speciality — matched to your condition';
  }

  /// Fetch all doctors and return recommendations ranked by:
  /// 1. Speciality match to diagnosis (matched > unmatched)
  /// 2. Star rating (higher first)
  /// 3. Total experience (more transfers = more experience)
  static Future<List<DoctorRecommendation>> getRecommendations(
    String diagnosis,
  ) async {
    final doctors = await AuthService.getAllDoctors();
    if (doctors.isEmpty) return [];

    final recommendations = <DoctorRecommendation>[];

    for (final doc in doctors) {
      final rating = computeStarRating(doc);
      final isMatch = matchesSpeciality(doc.speciality, diagnosis);
      if (!isMatch) continue; // only show matched specialities

      recommendations.add(DoctorRecommendation(
        doctor: doc,
        starRating: rating,
        matchReason: _matchReason(doc.speciality, diagnosis),
        isTopRated: rating >= 4.0,
      ));
    }

    // Sort: top-rated first, then by totalTransfers (experience)
    recommendations.sort((a, b) {
      final ratingCmp = b.starRating.compareTo(a.starRating);
      if (ratingCmp != 0) return ratingCmp;
      return b.doctor.totalTransfers.compareTo(a.doctor.totalTransfers);
    });

    // Return top 5
    return recommendations.take(5).toList();
  }
}
