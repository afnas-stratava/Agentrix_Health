import * as ImagePicker from 'expo-image-picker';
import { Directory, File, Paths } from 'expo-file-system';
import { log } from '@/lib/logger';

/**
 * Meal photo capture.
 *
 * The photo is stored on the device and never uploaded — there is no vision
 * model in this build, so it serves as a visual record attached to the entry
 * rather than as an input to macro estimation. See `recognize.ts` for why that
 * distinction is stated rather than glossed over.
 */

const MEALS_DIRECTORY = 'meal-photos';

export class PhotoCancelled extends Error {
  constructor() {
    super('Photo capture cancelled');
    this.name = 'PhotoCancelled';
  }
}

export class PhotoPermissionDenied extends Error {
  constructor(readonly kind: 'camera' | 'library') {
    super(
      kind === 'camera'
        ? 'Camera access is required to photograph a meal'
        : 'Photo library access is required to attach a meal photo',
    );
    this.name = 'PhotoPermissionDenied';
  }
}

/**
 * Picker URIs point at OS-managed caches iOS is free to purge between
 * launches; a food log whose thumbnails vanish overnight looks broken.
 */
function persistLocally(sourceUri: string): string {
  try {
    const directory = new Directory(Paths.document, MEALS_DIRECTORY);
    if (!directory.exists) directory.create({ intermediates: true });

    const extension = sourceUri.split('.').pop()?.toLowerCase() ?? 'jpg';
    const destination = new File(directory, `${Date.now()}.${extension}`);
    new File(sourceUri).copy(destination);

    return destination.uri;
  } catch (error) {
    log.warn('nutrition', 'Could not persist meal photo — using the cache URI', error);
    return sourceUri;
  }
}

/**
 * Meal thumbnails render at ~44 px and the full photo at card width, so a
 * 12-megapixel original is pure storage cost. 0.5 quality is indistinguishable
 * at these sizes and roughly a tenth of the bytes.
 */
const PICKER_OPTIONS: ImagePicker.ImagePickerOptions = {
  mediaTypes: ['images'],
  allowsMultipleSelection: false,
  quality: 0.5,
  allowsEditing: false,
};

export async function captureMealPhoto(): Promise<string> {
  const permission = await ImagePicker.requestCameraPermissionsAsync();
  if (!permission.granted) throw new PhotoPermissionDenied('camera');

  const result = await ImagePicker.launchCameraAsync(PICKER_OPTIONS);
  if (result.canceled || !result.assets?.[0]) throw new PhotoCancelled();

  return persistLocally(result.assets[0].uri);
}

export async function pickMealPhoto(): Promise<string> {
  const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
  if (!permission.granted) throw new PhotoPermissionDenied('library');

  const result = await ImagePicker.launchImageLibraryAsync(PICKER_OPTIONS);
  if (result.canceled || !result.assets?.[0]) throw new PhotoCancelled();

  return persistLocally(result.assets[0].uri);
}
