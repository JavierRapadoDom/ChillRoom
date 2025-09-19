import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chillroom/services/feedback_service.dart';

class FeedbackSheet {
  static const _accent = Color(0xFFE3A62F);

  static const List<String> categorias = [
    'Sugerencia',
    'Bug / Error',
    'Rendimiento',
    'Experiencia de usuario',
    'Funcionalidad faltante',
    'Otro',
  ];

  static Future<void> show(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final ctrlMsg = TextEditingController();
    final ctrlVersion = TextEditingController(); // opcional
    final ctrlDevice  = TextEditingController(); // opcional
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
        return StatefulBuilder(builder: (ctx, setState) {
          Future<void> submit() async {
            if (loading) return;
            if (!(formKey.currentState?.validate() ?? false)) return;
            HapticFeedback.lightImpact();
            setState(() => loading = true);

            final err = await FeedbackService.instance.enviar(
              categoria: categoria!,
              mensaje: ctrlMsg.text,
              appVersion: ctrlVersion.text.trim().isEmpty ? null : ctrlVersion.text.trim(),
              deviceInfo: ctrlDevice.text.trim().isEmpty ? null : ctrlDevice.text.trim(),
            );

            if (!ctx.mounted) return;
            if (err != null) {
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(err)));
              setState(() => loading = false);
              return;
            }

            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('¡Gracias por tu feedback!')),
            );
          }

          final mq = MediaQuery.of(ctx);
          InputBorder _b([Color? c]) => OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c ?? Colors.grey.shade300),
          );

          return Padding(
            padding: EdgeInsets.only(
              left: 18, right: 18, top: 12, bottom: mq.viewInsets.bottom + 18,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36, height: 4, margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const Text('Enviar feedback',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),

                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    items: categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    value: categoria,
                    onChanged: (v) => setState(() => categoria = v),
                    decoration: InputDecoration(
                      labelText: 'Categoría',
                      filled: true, fillColor: Colors.white,
                      border: _b(), enabledBorder: _b(), focusedBorder: _b(_accent),
                    ),
                    validator: (v) => v == null ? 'Selecciona una categoría' : null,
                  ),

                  const SizedBox(height: 12),
                  TextFormField(
                    controller: ctrlMsg,
                    minLines: 4, maxLines: 6, maxLength: 1000,
                    decoration: InputDecoration(
                      labelText: 'Cuéntanos tu feedback',
                      hintText: 'Describe brevemente tu sugerencia o problema…',
                      alignLabelWithHint: true, filled: true, fillColor: Colors.white,
                      border: _b(), enabledBorder: _b(), focusedBorder: _b(_accent),
                    ),
                    validator: (v) => (v == null || v.trim().length < 10)
                        ? 'Mínimo 10 caracteres' : null,
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: ctrlVersion,
                          decoration: InputDecoration(
                            labelText: 'Versión app (opcional)',
                            border: _b(), enabledBorder: _b(), focusedBorder: _b(_accent),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: ctrlDevice,
                          decoration: InputDecoration(
                            labelText: 'Dispositivo (opcional)',
                            hintText: 'p.ej. Pixel 7 / Android 14',
                            border: _b(), enabledBorder: _b(), focusedBorder: _b(_accent),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: ElevatedButton(
                      onPressed: loading ? null : submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: loading
                          ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
                      )
                          : const Text('ENVIAR', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }
}
