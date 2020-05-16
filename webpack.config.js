const VueLoaderPlugin = require('vue-loader/lib/plugin')

module.exports = {
  entry: './js/main.js',
  output: {
    path: `${__dirname}/public/`,
    filename: 'gion.js'
  },
  module: {
    rules: [
      {
        test: /\.vue$/,
        loader: 'vue-loader'
      },
      {
        enforce: "pre",
        exclude: /node_modules/,
        test: /\.js$/,
        loader: 'eslint-loader'
      },
      {
        test: /\.js$/,
        loader: 'babel-loader',
        exclude: /node_modules/,
        options: {
          presets: [
            "@babel/preset-env"
          ],
        },
      },
    ]
  },
  plugins: [
    new VueLoaderPlugin()
  ],
  resolve: {
    alias: {
      'vue$': 'vue/dist/vue.esm.js',
    }
  }
}

