module.exports = function(grunt) {
    grunt.initConfig({
      concat: {
        dist: {
          files: {
          '.tmp/js/add.js': [ 'js/add.js', 'js/c.js'],
          '.tmp/js/e.js': [ 'js/e.js', 'js/c.js'],
          '.tmp/js/entrance.js': [ 'js/entrance.js', 'js/c.js'],
          '.tmp/js/settings.js': [ 'js/settings.js', 'js/c.js'],
          '.tmp/js/subscription.js': [ 'js/subscription.js', 'js/c.js'],
          },
        },
      },
      uglify: {
        build: {
          files: [{
            expand: true,
            cwd: '.tmp/js/',
            src: '*.js',
            dest: 'public/static/'
          }]
        }
      },
    });
    grunt.loadNpmTasks('grunt-contrib-uglify');
    grunt.loadNpmTasks('grunt-contrib-concat');
    grunt.registerTask('default', ['concat', 'uglify']);
};
