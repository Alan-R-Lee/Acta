import fs from '@ohos.file.fs';
import common from '@ohos.app.ability.common';

export class MediaAssetService {
  static async persistPickedImage(context: common.UIAbilityContext, sourceUri: string, prefix: string): Promise<string> {
    if (!sourceUri) {
      return '';
    }

    const safePrefix = prefix.replace(/[^a-zA-Z0-9_]/g, '_');
    const targetPath = `${context.filesDir}/${safePrefix}_${Date.now()}.jpg`;

    try {
      await fs.copyFile(sourceUri, targetPath);
      return `file://${targetPath}`;
    } catch (error) {
      console.error('Failed to persist picked image.');
      return sourceUri;
    }
  }
}
