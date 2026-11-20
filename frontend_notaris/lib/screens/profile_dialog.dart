import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets/edit_dialog.dart';
import '../core/widgets/transaction_review_dialog.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../services/profile_api_service.dart';

Future<void> showOwnProfile(BuildContext context) async {
  var dirty = false, busy = false;
  await showEditDialog<void>(
    context: context,
    dirty: () => dirty,
    saving: () => busy,
    discardBackgroundColor: Colors.white,
    builder: (_) => ProfileDialog(
      activity: (d, b) {
        dirty = d;
        busy = b;
      },
    ),
  );
}

class ProfileDialog extends ConsumerStatefulWidget {
  const ProfileDialog({super.key, required this.activity});
  final void Function(bool, bool) activity;
  @override
  ConsumerState<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends ConsumerState<ProfileDialog> {
  final name = TextEditingController(),
      phone = TextEditingController(),
      address = TextEditingController();
  final form = GlobalKey<FormState>();
  OwnProfile? base;
  bool editing = false, busy = false, uncertain = false;
  String? message;
  bool get dirty =>
      editing &&
      base != null &&
      (name.text != base!.nama ||
          phone.text != (base!.noTelp ?? '') ||
          address.text != (base!.alamat ?? ''));
  void changed() {
    widget.activity(dirty, busy);
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    for (final c in [name, phone, address]) {
      c.addListener(changed);
    }
  }

  @override
  void dispose() {
    for (final c in [name, phone, address]) {
      c.removeListener(changed);
      c.dispose();
    }
    super.dispose();
  }

  void edit(OwnProfile v) {
    base = v;
    name.text = v.nama;
    phone.text = v.noTelp ?? '';
    address.text = v.alamat ?? '';
    setState(() {
      editing = true;
      uncertain = false;
      message = null;
    });
    changed();
  }

  Future<void> refresh() async {
    if (busy) return;
    if (dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Buang perubahan?'),
          content: const Text(
            'Refresh akan memuat profil server dan membuang draft lokal.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Lanjut edit'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Buang perubahan'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() {
      editing = false;
      uncertain = false;
      message = null;
    });
    widget.activity(false, false);
    ref.invalidate(ownProfileProvider);
  }

  Future<void> save() async {
    if (busy ||
        uncertain ||
        !editing ||
        !ref.read(profileEditingEnabledProvider) ||
        !allowsOwnProfile(ref.read(authControllerProvider).session) ||
        form.currentState?.validate() != true) {
      return;
    }
    final expected = base!;
    final actorToken = ref.read(authControllerProvider).session!.token;
    setState(() {
      busy = true;
      message = null;
    });
    widget.activity(dirty, true);
    var acked = false;
    try {
      final api = ref.read(profileApiProvider);
      final ack = await api.save(
        expectedRevision: expected.revision,
        nama: name.text,
        noTelp: phone.text.trim().isEmpty ? null : phone.text,
        alamat: address.text.trim().isEmpty ? null : address.text,
      );
      acked = true;
      final readback = await api.read();
      if (readback.id != expected.id || readback.revision < ack.revision) {
        throw StateError('Readback tidak cocok.');
      }
      await ref
          .read(authControllerProvider.notifier)
          .refreshCurrentPermissions();
      if (!mounted ||
          ref.read(authControllerProvider).session?.token != actorToken) {
        return;
      }
      ref.invalidate(ownProfileProvider);
      setState(() {
        base = readback;
        editing = false;
        message = 'Profil tersimpan dan telah dibaca kembali dari server.';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          message = acked
              ? 'Profil mungkin sudah tersimpan; readback atau refresh sesi belum terverifikasi. Refresh, jangan kirim ulang.'
              : profileError(e);
          uncertain = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        widget.activity(dirty, false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final permitted = allowsOwnProfile(
      ref.watch(authControllerProvider).session,
    );
    final result = permitted ? ref.watch(ownProfileProvider) : null;
    final mayEdit = ref.watch(profileEditingEnabledProvider);
    return TransactionReviewDialog(
      title: 'Profile Akun',
      subtitle: 'Informasi pribadi · Akun terautentikasi saat ini',
      width: 680,
      canClose: !busy,
      onClose: () => cancelEditDialog(context),
      body: !permitted
          ? const Text(
              'Profil memerlukan sesi online P0 yang valid. Perubahan offline tidak tersedia.',
            )
          : result!.when(
              skipLoadingOnRefresh: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(profileError(e)),
              data: (v) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'AKUN SAAT INI',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  for (final entry in <String, String>{
                    'Nama': v.nama,
                    'Username': v.username,
                    'Email': v.email,
                    'Group': '${v.groupName} · ${v.groupKind}',
                    'Status': 'Aktif',
                    'Revisi': '${v.revision}',
                  }.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Text('${entry.key}: ${entry.value}'),
                    ),
                  const Divider(height: 28),
                  if (!editing) ...[
                    Text('Nomor Telepon: ${v.noTelp ?? 'Belum diisi'}'),
                    const SizedBox(height: 10),
                    Text('Alamat: ${v.alamat ?? 'Belum diisi'}'),
                    const SizedBox(height: 14),
                    const Text(
                      'Username, email, Group, dan status hanya dapat dibaca. Password dan avatar belum tersedia pada Profile V1.',
                    ),
                  ],
                  if (editing)
                    Form(
                      key: form,
                      child: Column(
                        children: [
                          TextFormField(
                            key: const Key('profile-nama'),
                            controller: name,
                            enabled: !busy,
                            maxLength: 160,
                            decoration: const InputDecoration(
                              labelText: 'Nama',
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Nama wajib diisi.'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            key: const Key('profile-phone'),
                            controller: phone,
                            enabled: !busy,
                            maxLength: 32,
                            decoration: const InputDecoration(
                              labelText: 'Nomor Telepon (opsional)',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            key: const Key('profile-address'),
                            controller: address,
                            enabled: !busy,
                            maxLength: 255,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Alamat (opsional)',
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!mayEdit)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(ref.watch(profileEditingExplanationProvider)),
                    ),
                ],
              ),
            ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(message!, key: const Key('profile-message')),
            ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('profile-refresh'),
                onPressed: busy || !permitted ? null : refresh,
                child: const Text('Refresh'),
              ),
              TextButton(
                key: const Key('profile-cancel'),
                onPressed: busy ? null : () => cancelEditDialog(context),
                child: const Text('Tutup / Batal'),
              ),
              if (!editing)
                FilledButton(
                  key: const Key('profile-edit'),
                  onPressed:
                      busy || !permitted || !mayEdit || result?.asData == null
                      ? null
                      : () => edit(result!.requireValue),
                  child: const Text('Ubah Profil'),
                ),
              if (editing)
                FilledButton(
                  key: const Key('profile-save'),
                  onPressed: busy || uncertain || !permitted || !mayEdit
                      ? null
                      : save,
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Simpan'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
