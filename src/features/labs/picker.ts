import * as DocumentPicker from 'expo-document-picker';
import * as ImagePicker from 'expo-image-picker';
import { Directory, File, Paths } from 'expo-file-system';
import { LabUploadRequestSchema, type LabUploadRequest } from '@/schemas/labs';
import { log } from '@/lib/logger';

export class PickerCancelled extends Error {
  constructor() {
    super('Selection cancelled');
    this.name = 'PickerCancelled';
  }
}

export class PickerPermissionDenied extends Error {
  constructor(readonly kind: 'camera' | 'library') {
    super(
      kind === 'camera'
        ? 'Camera access is required to photograph a report'
        : 'Photo library access is required to attach a report',
    );
    this.name = 'PickerPermissionDenied';
  }
}

const ACCEPTED_MIME = new Set([
  'application/pdf',
  'image/jpeg',
  'image/png',
  'image/heic',
  'image/heif',
]);

const LABS_DIRECTORY = 'lab-reports';

/**
 * Picker URIs point at OS-managed caches that iOS is free to purge. Anything
 * we intend to re-parse later has to be copied into the app's document
 * directory first, or the user's report silently vanishes between sessions.
 */
function persistLocally(sourceUri: string, fileName: string): string {
  try {
    const directory = new Directory(Paths.document, LABS_DIRECTORY);
    if (!directory.exists) directory.create({ intermediates: true });

    const safeName = `${Date.now()}-${fileName.replace(/[^\w.\-]+/g, '_')}`;
    const destination = new File(directory, safeName);
    new File(sourceUri).copy(destination);

    return destination.uri;
  } catch (error) {
    // A copy failure is not fatal — the cache URI still works for this session.
    log.warn('labs', 'Could not persist report into app storage', error);
    return sourceUri;
  }
}

function sizeOf(uri: string, fallback: number | null | undefined): number {
  if (fallback != null && fallback > 0) return fallback;
  try {
    const size = new File(uri).size;
    return size ?? 0;
  } catch {
    return 0;
  }
}

function normaliseMime(mimeType: string | null | undefined, name: string): string {
  if (mimeType && ACCEPTED_MIME.has(mimeType.toLowerCase())) return mimeType.toLowerCase();

  const extension = name.split('.').pop()?.toLowerCase();
  switch (extension) {
    case 'pdf':
      return 'application/pdf';
    case 'png':
      return 'image/png';
    case 'heic':
      return 'image/heic';
    case 'heif':
      return 'image/heif';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    default:
      return mimeType?.toLowerCase() ?? 'application/octet-stream';
  }
}

/** PDF or image, via the system Files browser. */
export async function pickDocument(): Promise<LabUploadRequest> {
  const result = await DocumentPicker.getDocumentAsync({
    type: [...ACCEPTED_MIME],
    copyToCacheDirectory: true,
    multiple: false,
  });

  if (result.canceled || !result.assets?.[0]) throw new PickerCancelled();

  const asset = result.assets[0];
  const name = asset.name || 'lab-report.pdf';
  const mimeType = normaliseMime(asset.mimeType, name);
  const uri = persistLocally(asset.uri, name);

  return LabUploadRequestSchema.parse({
    uri,
    name,
    mimeType,
    sizeBytes: sizeOf(uri, asset.size),
    source: mimeType === 'application/pdf' ? 'pdf' : 'image',
  });
}

/** Existing photo of a printed report. */
export async function pickImage(): Promise<LabUploadRequest> {
  const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
  if (!permission.granted) throw new PickerPermissionDenied('library');

  const result = await ImagePicker.launchImageLibraryAsync({
    mediaTypes: ['images'],
    allowsMultipleSelection: false,
    // Lab reports are dense text; aggressive compression destroys OCR accuracy.
    quality: 1,
    exif: false,
  });

  if (result.canceled || !result.assets[0]) throw new PickerCancelled();

  const asset = result.assets[0];
  const name = asset.fileName ?? `lab-photo-${Date.now()}.jpg`;
  const mimeType = normaliseMime(asset.mimeType, name);
  const uri = persistLocally(asset.uri, name);

  return LabUploadRequestSchema.parse({
    uri,
    name,
    mimeType,
    sizeBytes: sizeOf(uri, asset.fileSize),
    source: 'image',
  });
}

/** Live capture of a paper report. */
export async function captureImage(): Promise<LabUploadRequest> {
  const permission = await ImagePicker.requestCameraPermissionsAsync();
  if (!permission.granted) throw new PickerPermissionDenied('camera');

  const result = await ImagePicker.launchCameraAsync({
    mediaTypes: ['images'],
    quality: 1,
    exif: false,
  });

  if (result.canceled || !result.assets[0]) throw new PickerCancelled();

  const asset = result.assets[0];
  const name = asset.fileName ?? `lab-scan-${Date.now()}.jpg`;
  const mimeType = normaliseMime(asset.mimeType, name);
  const uri = persistLocally(asset.uri, name);

  return LabUploadRequestSchema.parse({
    uri,
    name,
    mimeType,
    sizeBytes: sizeOf(uri, asset.fileSize),
    source: 'image',
  });
}

/** Best-effort cleanup when a report is deleted from the library. */
export function deleteStoredFile(uri: string | null): void {
  if (!uri || !uri.includes(LABS_DIRECTORY)) return;
  try {
    const file = new File(uri);
    if (file.exists) file.delete();
  } catch (error) {
    log.warn('labs', 'Could not delete stored report file', error);
  }
}
