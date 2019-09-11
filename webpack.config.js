const VueLoaderPlugin = require('vue-loader/lib/plugin')

module.exports = {
  entry: './js/main.js',
  output: {
    path: `${__dirname}/public/static/`,
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
        loader: 'babel-loader'
      },
      {
        test: /\.css$/,
        use: [
          'vue-style-loader',
          'css-loader'
        ]
      }
    ]
  },
  plugins: [
    new VueLoaderPlugin()
  ]
}

