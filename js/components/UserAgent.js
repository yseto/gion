/* vim:set ts=2 sts=2 sw=2:*/
export default function(args, then, error) {
  const superagent = require('superagent');
  var agent = superagent.post(args.url);
  agent = args.jsonRequest ? agent : agent.type('form');

  if (error === undefined) { error = function() {} }

  agent.set({
    'X-Requested-With': 'XMLHttpRequest',
    'X-CSRF-Token': document.getElementsByName('csrf-token')[0].content,
    'Cache-Control': 'no-cache'
  })
  .send(args.data)
  .on('error', error)
  .end(then);
}
