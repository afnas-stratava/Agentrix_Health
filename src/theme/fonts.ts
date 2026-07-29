import {
  InterTight_400Regular,
  InterTight_500Medium,
  InterTight_600SemiBold,
  InterTight_700Bold,
  InterTight_800ExtraBold,
  InterTight_900Black,
} from '@expo-google-fonts/inter-tight';

/**
 * Inter Tight is the product typeface — the compact display cut of Inter, which
 * is what keeps headline tracking tight at large sizes without manual kerning.
 *
 * React Native does not synthesise weights: every face is registered under its
 * own family name, and `fontWeight` alone will not reach it. So each weight is
 * loaded separately here and `tailwind.config.js` maps the `font-*` utilities
 * onto the matching family. The two lists have to stay in lockstep.
 */
export const appFonts = {
  InterTight_400Regular,
  InterTight_500Medium,
  InterTight_600SemiBold,
  InterTight_700Bold,
  InterTight_800ExtraBold,
  InterTight_900Black,
} as const;
