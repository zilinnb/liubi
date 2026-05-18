import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import '../utils/live_photo_util.dart';

class AssetPickResult {
  final List<String> imagePaths;
  final List<Uint8List> imageThumbs;
  final List<String> liveVideoPaths;
  final List<bool> isLiveList;

  AssetPickResult({
    required this.imagePaths,
    required this.imageThumbs,
    required this.liveVideoPaths,
    required this.isLiveList,
  });
}

class ImagePickerUtil {
  static Future<AssetPickResult?> pickImages(
    BuildContext context, {
    int maxAssets = 9,
  }) async {
    final PermissionState ps =
        await PhotoManager.requestPermissionExtend();
    if (!ps.hasAccess) {
      return null;
    }

    final List<AssetEntity>? assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: maxAssets,
        requestType: RequestType.image,
        textDelegate: const AssetPickerTextDelegate(),
        filterOptions: FilterOptionGroup(
          imageOption: const FilterOption(
            sizeConstraint: SizeConstraint(
              minWidth: 1,
              minHeight: 1,
            ),
          ),
        ),
      ),
    );

    if (assets == null || assets.isEmpty) {
      debugPrint('[ImagePicker] pickAssets returned null or empty');
      return null;
    }

    debugPrint('[ImagePicker] picked ${assets.length} assets');

    final imgPaths = <String>[];
    final imgThumbs = <Uint8List>[];
    final vidPaths = <String>[];
    final isLiveList = <bool>[];

    for (int i = 0; i < assets.length; i++) {
      final asset = assets[i];
      final file = await asset.originFile;
      if (file == null) {
        debugPrint('[ImagePicker] asset ${asset.id} originFile is null');
        continue;
      }
      final filePath = file.path;
      debugPrint('[ImagePicker] asset=${asset.id}, path=$filePath, exists=${file.existsSync()}');
      imgPaths.add(filePath);

      final thumb = await asset.thumbnailDataWithSize(
        const ThumbnailSize(800, 800),
        quality: 90,
      );
      imgThumbs.add(thumb ?? Uint8List(0));

      final title = asset.title ?? '';
      bool isMotion = title.toUpperCase().startsWith('MVIMG') ||
          LivePhotoUtil.isCachedMotionPhoto(asset.id);

      if (!isMotion) {
        try {
          isMotion = asset.isLivePhoto;
        } catch (_) {}

        if (!isMotion) {
          isMotion = await LivePhotoUtil.isMotionPhotoByAsset(asset);
        }
      }

      isLiveList.add(isMotion);

      if (isMotion) {
        debugPrint('[ImagePicker] detected motion photo: $filePath');
        final vp = await LivePhotoUtil.extractVideo(filePath);
        if (vp != null) {
          vidPaths.add(vp);
          debugPrint('[ImagePicker] extracted video: $vp');
        } else {
          vidPaths.add('');
        }
      } else {
        vidPaths.add('');
      }
    }

    if (imgPaths.isEmpty) return null;

    return AssetPickResult(
      imagePaths: imgPaths,
      imageThumbs: imgThumbs,
      liveVideoPaths: vidPaths,
      isLiveList: isLiveList,
    );
  }

  static Future<String?> pickSingleImage(BuildContext context) async {
    final result = await pickImages(context, maxAssets: 1);
    if (result == null || result.imagePaths.isEmpty) return null;
    return result.imagePaths.first;
  }
}
