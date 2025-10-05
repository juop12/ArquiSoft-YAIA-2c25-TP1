#!/usr/bin/env node

// Script to test custom metrics by sending sample data to StatsD
const StatsD = require('node-statsd');

const statsd = new StatsD({
  host: process.env.STATSD_HOST || 'localhost',
  port: process.env.STATSD_PORT || 8125,
  prefix: 'arvault.exchange.'
});

console.log('Sending test metrics to StatsD...');

// Simulate some exchange operations
const currencies = ['USD', 'ARS', 'EUR'];
const exchangePairs = [
  { from: 'USD', to: 'ARS', rate: 1450 },
  { from: 'ARS', to: 'USD', rate: 0.00069 },
  { from: 'USD', to: 'EUR', rate: 0.85 },
  { from: 'EUR', to: 'USD', rate: 1.18 }
];

// Send test data for 30 seconds
let counter = 0;
const interval = setInterval(() => {
  counter++;
  
  // Simulate successful exchanges
  const pair = exchangePairs[Math.floor(Math.random() * exchangePairs.length)];
  const amount = Math.random() * 1000 + 100; // Random amount between 100-1100
  
  // Track successful exchange
  statsd.increment('successful');
  
  // Track volume by currency
  statsd.increment(`volume.${pair.from}`, amount);
  statsd.increment(`volume.${pair.to}`, amount * pair.rate);
  
  // Track net position
  statsd.gauge(`net.${pair.from}`, amount);
  statsd.gauge(`net.${pair.to}`, -amount * pair.rate);
  
  // Track exchange rate
  statsd.gauge(`rate.${pair.from}_${pair.to}`, pair.rate);
  statsd.gauge(`rate.${pair.to}_${pair.from}`, 1/pair.rate);
  
  // Track exchange duration (simulate 200-400ms)
  const duration = Math.random() * 200 + 200;
  statsd.timing('duration', duration);
  
  // Occasionally simulate a failed exchange
  if (Math.random() < 0.1) { // 10% failure rate
    statsd.increment('failed');
  }
  
  console.log(`Sent test data batch ${counter}`);
  
  if (counter >= 30) {
    clearInterval(interval);
    console.log('Test completed! Check your Grafana dashboard.');
    process.exit(0);
  }
}, 1000);

console.log('Test started. Will run for 30 seconds...');
