#!/usr/bin/env node
require('coffeescript/register');
var attendance = require('./attendance');
module.exports = attendance;
if (require.main === module) attendance.main();
