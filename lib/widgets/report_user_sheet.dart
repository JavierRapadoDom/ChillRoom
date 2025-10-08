import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/report_service.dart';


class ReportUserSheet {
  static const _accent = Color(0xFFE3A62F);
  static const _accentDark = Color(0xFFD69412);

  static const List<String> categorias = [
    'Perfil falso',
    'Spam / Estafa',
    'Acoso / Insultos',
    'Contenido inapropiado',
    'Discriminación',
    'Suplantación de identidad',
    'Otro',
  ];

  static Future<void> show(
      BuildContext context, {
        required String reportedUserId,
      }) async {
    final formKey = GlobalKey<FormState>();
    final ctrlMsg = TextEditingController();
    String? categoria;

    bool loading = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            Future<void> submit() async {
              if (loading) return;
              if (!(formKey.currentState?.validate() ?? false)) return;

              HapticFeedback.lightImpact();
              setState(() => loading = true);

              final err = await ReportService().crearReporte(
                reportedUserId: reportedUserId,
                categoria: categoria!,
                mensaje: ctrlMsg.text,
              );

              if (!ctx.mounted) return;
              if (err != null) {
                ScaffoldMessenger.of(ctx)
                    .showSnackBar(SnackBar(content: Text(err)));
                setState(() => loading = false);
                return;
              }

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Reporte enviado. ¡Gracias por avisar!')),
              );
            }

            final mq = MediaQuery.of(ctx);
            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 12,
                bottom: mq.viewInsets.bottom + 18,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const Text(
                      'Reportar usuario',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .2,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Categoría
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Motivo',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: _accent, width: 1.6),
                        ),
                      ),
                      items: categorias
                          .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c),
                      ))
                          .toList(),
                      value: categoria,
                      onChanged: (v) => setState(() => categoria = v),
                      validator: (v) =>
                      v == null ? 'Selecciona un motivo' : null,
                    ),
                    const SizedBox(height: 12),

                    // Mensaje
                    TextFormField(
                      controller: ctrlMsg,
                      minLines: 4,
                      maxLines: 6,
                      maxLength: 500,
                      decoration: InputDecoration(
                        labelText: 'Cuéntanos qué ocurrió',
                        alignLabelWithHint: true,
                        hintText:
                        'Explica brevemente por qué reportas a este usuario…',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: _accent, width: 1.6),
                        ),
                      ),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.length < 10) {
                          return 'Mínimo 10 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tu reporte es confidencial. Nuestro equipo lo revisará.',
                      style: TextStyle(
                        color: Colors.black.withOpacity(.55),
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Botón enviar
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: loading ? null : submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: loading
                            ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.6,
                            color: Colors.white,
                          ),
                        )
                            : const Text(
                          'ENVIAR REPORTE',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, letterSpacing: .2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
