require('dotenv').config()

console.log(process.env)

const { ApolloServer } = require('apollo-server');
const { ApolloGateway } = require('@apollo/gateway');

console.log('start the server...');

const gateway = new ApolloGateway();
const server = new ApolloServer({
  gateway,
  debug: true,
  // Subscriptions are unsupported but planned for a future Gateway version.
  subscriptions: false
});

server.listen().then((result) => {
  console.log("Success", result);
  console.log(result.url)
}).catch(err => {console.error(err)});