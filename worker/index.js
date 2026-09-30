const keys = require('./keys');
const redis = require('redis');

const redisOptions = {
  host: keys.redisHost,
  port: keys.redisPort,
  auth_pass: keys.redisPassword,
  tls: keys.redisTls ? {} : undefined,
  retry_strategy: () => 1000
};
const redisClient = redis.createClient(redisOptions);
const sub = redisClient.duplicate();

function fib(index) {
  if (index < 2) return 1;
  return fib(index - 1) + fib(index - 2);
}

sub.on('message', (channel, message) => {
  redisClient.hset('values', message, fib(parseInt(message)));
});
sub.subscribe('insert');
