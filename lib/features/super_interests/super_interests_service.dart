import 'package:supabase_flutter/supabase_flutter.dart';
import 'super_interests_models.dart';

class SuperInterestsService {
  SuperInterestsService._();
  static final instance = SuperInterestsService._();

  final _sb = Supabase.instance.client;

  String _uid() {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) throw StateError('No hay usuario autenticado');
    return uid;
  }

  Future<SuperInterestData?> fetch() async {
    final uid = _uid();

    final m = await _sb
        .from('perfiles')
        .select('super_interes, super_interes_data')
        .eq('usuario_id', uid)
        .maybeSingle();

    if (m == null) return null;

    final type = SuperInterestTypeX.fromKey(m['super_interes'] as String?);
    final dataMap = (m['super_interes_data'] as Map?)?.cast<String, dynamic>();

    if (dataMap == null) return SuperInterestData(type: type);

    return SuperInterestData.fromJson({
      'type': type.asKey,
      ...dataMap,
    });
  }

  Future<void> save(SuperInterestData data) async {
    final uid = _uid();

    await _sb.from('perfiles').update({
      'super_interes': data.type.asKey,
      'super_interes_data': data.toJson(),
    }).eq('usuario_id', uid);
  }
}
