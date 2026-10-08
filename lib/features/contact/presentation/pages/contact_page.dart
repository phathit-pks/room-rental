import 'package:file_picker/file_picker.dart' as picker;
import 'package:flutter/material.dart';
import 'package:room_rental/core/config/supabase_config.dart';
import 'package:room_rental/core/theme/app_colors.dart';
import 'package:room_rental/core/utils/google_maps_location.dart';
import 'package:room_rental/core/utils/thumbnail_compressor.dart';
import 'package:room_rental/features/auth/presentation/widgets/client_auth_button.dart';
import 'package:room_rental/features/listings/data/repositories/scraped_listing_repository.dart';
import 'package:room_rental/features/locations/data/location_store.dart';
import 'package:room_rental/shared/widgets/app_logo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleFieldKey = GlobalKey<FormFieldState<String>>();
  final _priceMinFieldKey = GlobalKey<FormFieldState<String>>();
  final _priceMaxFieldKey = GlobalKey<FormFieldState<String>>();
  final _provinceFieldKey = GlobalKey<FormFieldState<String>>();
  final _districtFieldKey = GlobalKey<FormFieldState<String>>();
  final _mapUrlFieldKey = GlobalKey<FormFieldState<String>>();
  final _repository = const ScrapedListingRepository();
  final _title = TextEditingController();
  final _priceMin = TextEditingController();
  final _priceMax = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _sourceUrl = TextEditingController();
  final _mapUrl = TextEditingController();
  String _type = 'room';
  String _currency = 'LAK';
  String? _province;
  String? _district;
  String? _village;
  CompressedThumbnail? _thumbnail;
  final List<CompressedThumbnail> _galleryImages = [];
  bool _processingGallery = false;
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (SupabaseConfig.client?.auth.currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showClientSignInDialog(context);
      });
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _priceMin,
      _priceMax,
      _phone,
      _address,
      _sourceUrl,
      _mapUrl,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickThumbnail() async {
    final file = await picker.FilePicker.pickFile(type: picker.FileType.image);
    if (file == null) return;
    try {
      final bytes = await file.readAsBytes();
      final compressed = await ThumbnailCompressor.compress(bytes, file.name);
      if (mounted) setState(() => _thumbnail = compressed);
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  Future<void> _pickGalleryImages() async {
    final remaining = 4 - _galleryImages.length;
    if (remaining <= 0) {
      setState(() => _error = 'อัปโหลดรูปภายในได้ไม่เกิน 4 รูป');
      return;
    }
    final files = await picker.FilePicker.pickFiles(
      type: picker.FileType.image,
    );
    if (files.isEmpty) return;
    if (files.length > remaining) {
      setState(() => _error = 'เลือกเพิ่มได้อีกเพียง $remaining รูป');
      return;
    }
    setState(() {
      _processingGallery = true;
      _error = null;
    });
    try {
      final compressed = <CompressedThumbnail>[];
      for (final file in files) {
        compressed.add(
          await ThumbnailCompressor.compress(
            await file.readAsBytes(),
            file.name,
          ),
        );
      }
      if (mounted) setState(() => _galleryImages.addAll(compressed));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _processingGallery = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _scrollToFirstError();
      return;
    }
    final user = SupabaseConfig.client?.auth.currentUser;
    if (user == null) {
      await showClientSignInDialog(context);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (await _repository.hasClientSubmission()) {
        throw const FormatException(
          'บัญชีนี้ลงประกาศครบ 1 ห้องแล้ว ไม่สามารถเพิ่มห้องใหม่ได้',
        );
      }
      String? thumbnailUrl;
      if (_thumbnail != null) {
        thumbnailUrl = await _repository.uploadThumbnail(
          bytes: _thumbnail!.bytes,
          fileName: _thumbnail!.fileName,
        );
      }
      final galleryUrls = await _repository.uploadGalleryImages(
        _galleryImages
            .map((image) => (bytes: image.bytes, fileName: image.fileName))
            .toList(),
      );
      final minimumInput = int.tryParse(
        _priceMin.text.replaceAll(',', '').trim(),
      );
      final maximumInput = int.tryParse(
        _priceMax.text.replaceAll(',', '').trim(),
      );
      final minimum = minimumInput ?? maximumInput;
      final maximum = maximumInput ?? minimumInput;
      final metadata = user.userMetadata ?? const <String, dynamic>{};
      final submittedByName = (metadata['full_name'] ?? metadata['name'] ?? '')
          .toString()
          .trim();
      var mapLocation = GoogleMapsLocation.tryParse(_mapUrl.text);
      if (_mapUrl.text.trim().isNotEmpty &&
          (mapLocation?.latitude == null || mapLocation?.longitude == null)) {
        final response = await Supabase.instance.client.functions.invoke(
          'resolve-google-maps-link',
          body: {'url': _mapUrl.text.trim()},
        );
        final data = Map<String, dynamic>.from(response.data as Map);
        mapLocation = GoogleMapsLocation(
          url: (data['url'] ?? _mapUrl.text).toString(),
          latitude: (data['latitude'] as num?)?.toDouble(),
          longitude: (data['longitude'] as num?)?.toDouble(),
        );
        if (mapLocation.latitude == null || mapLocation.longitude == null) {
          throw const FormatException(
            'ไม่พบพิกัดจาก Google Maps Link กรุณาตรวจสอบลิงก์อีกครั้ง',
          );
        }
      }
      await _repository.saveDraft(
        rawText: '${_title.text.trim()} ${_address.text.trim()}',
        sourceUrl: _sourceUrl.text.trim(),
        status: 'pending_review',
        parsedData: {
          'manual_entry': true,
          'client_submission': true,
          'submitted_by_name': submittedByName,
          'submitted_by_email': user.email,
          'posted_at': DateTime.now().toUtc().toIso8601String(),
          'title': _title.text.trim(),
          'property_type': _type,
          'monthly_price': minimum ?? 0,
          'monthly_price_min': minimum,
          'monthly_price_max': maximum,
          'currency': _currency,
          'province': _province,
          'district': _district,
          'village': _village,
          'address': _address.text.trim(),
          'contact_phone': _phone.text.trim(),
          'source_url': _sourceUrl.text.trim(),
          'map_url': mapLocation?.url,
          'latitude': mapLocation?.latitude,
          'longitude': mapLocation?.longitude,
          'thumbnail_url': thumbnailUrl,
          'gallery_urls': galleryUrls,
        },
      );
      if (mounted) setState(() => _submitted = true);
    } on PostgrestException catch (exception) {
      final message = exception.code == '23505'
          ? 'บัญชีนี้ลงประกาศครบ 1 ห้องแล้ว ไม่สามารถเพิ่มห้องใหม่ได้'
          : exception.toString();
      if (mounted) setState(() => _error = message);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _scrollToFirstError() {
    for (final key in [
      _titleFieldKey,
      _priceMinFieldKey,
      _priceMaxFieldKey,
      _provinceFieldKey,
      _districtFieldKey,
      _mapUrlFieldKey,
    ]) {
      final fieldContext = key.currentContext;
      if (key.currentState?.hasError == true && fieldContext != null) {
        Scrollable.ensureVisible(
          fieldContext,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          alignment: 0.2,
        );
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back),
      ),
      title: const AppLogo(),
      actions: const [ClientAuthButton(), SizedBox(width: 20)],
    ),
    body: StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, _) {
        final signedIn = Supabase.instance.client.auth.currentUser != null;
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [context.colors.primaryContainer, context.colors.background],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: _submitted
                        ? _success()
                        : signedIn
                        ? _listingForm()
                        : _signInRequired(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _signInRequired() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        Icons.lock_person_outlined,
        size: 62,
        color: context.colors.primary,
      ),
      const SizedBox(height: 18),
      const Text(
        'เข้าสู่ระบบก่อนลงประกาศ',
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      const Text(
        'สมัครฟรีด้วย Google เพื่อส่งข้อมูลที่พักให้ Admin ตรวจสอบ',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 22),
      FilledButton.icon(
        onPressed: () => showClientSignInDialog(context),
        icon: const Icon(Icons.login),
        label: const Text('สมัครหรือเข้าสู่ระบบด้วย Google'),
      ),
    ],
  );

  Widget _success() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(
        radius: 34,
        backgroundColor: context.colors.successContainer,
        child: Icon(
          Icons.hourglass_top,
          size: 34,
          color: context.colors.success,
        ),
      ),
      const SizedBox(height: 18),
      const Text(
        'ส่งประกาศแล้ว',
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      const Text(
        'ประกาศอยู่ระหว่างรอ Admin ตรวจสอบประมาณ 3–5 วัน\nเมื่ออนุมัติแล้วจะแสดงบนเว็บไซต์',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 22),
      FilledButton(
        onPressed: () => Navigator.pushReplacementNamed(context, '/'),
        child: const Text('กลับหน้าแรก'),
      ),
    ],
  );

  Widget _listingForm() {
    final locations = LocationStore.instance.data;
    final provinces = locations.keys.toList();
    final districts = _province == null
        ? <String>[]
        : locations[_province]!.keys.toList();
    final villages = _province == null || _district == null
        ? <String>[]
        : locations[_province]![_district]!;
    final detectedMapLocation = GoogleMapsLocation.tryParse(_mapUrl.text);
    final hasDetectedCoordinates =
        detectedMapLocation?.latitude != null &&
        detectedMapLocation?.longitude != null;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ส่งข้อมูลที่พักฟรี',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          Text(
            'ทุกประกาศจะผ่านการตรวจสอบก่อนเผยแพร่',
            style: TextStyle(color: context.colors.textMuted),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: _submitting ? null : _pickThumbnail,
            icon: Icon(
              _thumbnail == null
                  ? Icons.add_photo_alternate_outlined
                  : Icons.check_circle_outline,
            ),
            label: Text(
              _thumbnail == null
                  ? 'เพิ่มรูปหน้าปก (ไม่เกิน 1 MB)'
                  : 'เลือกรูปแล้ว: ${_thumbnail!.fileName}',
            ),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(20)),
          ),
          if (_thumbnail != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(
                _thumbnail!.bytes,
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _submitting
                    ? null
                    : () => setState(() => _thumbnail = null),
                icon: const Icon(Icons.delete_outline),
                label: Text(
                  '${(_thumbnail!.bytes.lengthInBytes / 1024).ceil()} KB • ลบรูป',
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _submitting || _processingGallery
                ? null
                : _pickGalleryImages,
            icon: _processingGallery
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.collections_outlined),
            label: Text(
              _processingGallery
                  ? 'กำลังบีบอัดรูป...'
                  : 'เพิ่มรูปภายในห้อง (${_galleryImages.length}/4)',
            ),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(18)),
          ),
          if (_galleryImages.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(_galleryImages.length, (index) {
                final image = _galleryImages[index];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        image.bytes,
                        width: 132,
                        height: 96,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton.filled(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'ลบรูป',
                        onPressed: _submitting
                            ? null
                            : () => setState(
                                () => _galleryImages.removeAt(index),
                              ),
                        icon: const Icon(Icons.close, size: 16),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'ประเภทที่พัก *'),
            items: const [
              DropdownMenuItem(value: 'room', child: Text('ห้องแถว')),
              DropdownMenuItem(value: 'house', child: Text('บ้านเช่า')),
              DropdownMenuItem(value: 'apartment', child: Text('อพาร์ตเมนต์')),
            ],
            onChanged: (value) => setState(() => _type = value!),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: _titleFieldKey,
            controller: _title,
            decoration: const InputDecoration(labelText: 'ชื่อที่พัก *'),
            validator: _required,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: _priceMinFieldKey,
                  controller: _priceMin,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ราคาต่ำสุด/เดือน (ไม่บังคับ)',
                  ),
                  validator: _number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  key: _priceMaxFieldKey,
                  controller: _priceMax,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ราคาสูงสุด/เดือน (ไม่บังคับ)',
                  ),
                  validator: _maxPrice,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _currency,
                  decoration: const InputDecoration(labelText: 'สกุลเงิน'),
                  items: const ['LAK', 'THB', 'USD']
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _currency = value!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: _provinceFieldKey,
            initialValue: _province,
            decoration: const InputDecoration(labelText: 'แขวง *'),
            items: provinces
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: (v) => setState(() {
              _province = v;
              _district = null;
              _village = null;
            }),
            validator: (v) => v == null ? 'กรุณาเลือกแขวง' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: _districtFieldKey,
                  initialValue: _district,
                  decoration: const InputDecoration(labelText: 'เมือง *'),
                  items: districts
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: _province == null
                      ? null
                      : (v) => setState(() {
                          _district = v;
                          _village = null;
                        }),
                  validator: (v) => v == null ? 'กรุณาเลือกเมือง' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _village,
                  decoration: const InputDecoration(labelText: 'บ้าน'),
                  items: villages
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: _district == null
                      ? null
                      : (v) => setState(() => _village = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _address,
            decoration: const InputDecoration(labelText: 'ที่อยู่เพิ่มเติม'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            decoration: const InputDecoration(
              labelText: 'เบอร์โทร / WhatsApp (ไม่บังคับ)',
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _sourceUrl,
            decoration: const InputDecoration(
              labelText: 'ลิงก์ประกาศต้นทาง (ไม่บังคับ)',
              prefixIcon: Icon(Icons.link_outlined),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: _mapUrlFieldKey,
            controller: _mapUrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Google Maps link หรือพิกัด',
              helperText: _mapUrl.text.trim().isEmpty
                  ? 'ระบบจะเก็บทั้งลิงก์ Latitude และ Longitude'
                  : hasDetectedCoordinates
                  ? 'ตรวจพบ ${detectedMapLocation!.latitude}, ${detectedMapLocation.longitude}'
                  : 'ระบบจะแปลงลิงก์เป็นพิกัดอัตโนมัติตอนส่งข้อมูล',
              helperStyle: TextStyle(
                color: _mapUrl.text.trim().isNotEmpty && !hasDetectedCoordinates
                    ? Colors.orange.shade800
                    : context.colors.textMuted,
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              final location = GoogleMapsLocation.tryParse(value);
              return location == null
                  ? 'กรุณาใส่ Google Maps Link หรือ latitude, longitude'
                  : null;
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: context.colors.danger)),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _submitting || _processingGallery ? null : _submit,
            icon: _submitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(_submitting ? 'กำลังส่ง...' : 'ส่งให้ Admin ตรวจสอบ'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        ],
      ),
    );
  }

  String? _required(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'กรุณากรอกข้อมูล' : null;
  String? _number(String? value) =>
      value?.trim().isNotEmpty == true &&
          int.tryParse(value!.replaceAll(',', '')) == null
      ? 'กรุณากรอกตัวเลข'
      : null;
  String? _maxPrice(String? value) {
    if (value?.trim().isEmpty ?? true) return null;
    final error = _number(value);
    if (error != null) return error;
    final min = int.tryParse(_priceMin.text.replaceAll(',', '')) ?? 0;
    final max = int.parse(value!.replaceAll(',', ''));
    return max < min ? 'ต้องไม่น้อยกว่าราคาต่ำสุด' : null;
  }
}
