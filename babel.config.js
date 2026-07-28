/** @type {import('@babel/core').ConfigFunction} */
module.exports = function (api) {
  api.cache(true);

  return {
    presets: [
      ['babel-preset-expo', { jsxImportSource: 'nativewind' }],
      'nativewind/babel',
    ],
    plugins: [
      // react-native-worklets/plugin supersedes react-native-reanimated/plugin
      // for Reanimated 4.x and MUST remain the last entry in this list.
      'react-native-worklets/plugin',
    ],
  };
};
