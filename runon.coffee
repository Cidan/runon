#!/usr/bin/coffee
AWS = require 'aws-sdk'
config = require "#{__dirname}/config.json"
AWS.config.loadFromPath "#{__dirname}/config.json"
ec2 = new AWS.EC2()
mod_getopt = require 'posix-getopt'
async = require 'async'
spawn = require('child_process').spawn
util = require 'util'

tag = ""
cmd = ""
serial = false

opt_parser = new mod_getopt.BasicParser('st:c:', process.argv)
while ((option = opt_parser.getopt()) != undefined)
	if option.option == 't'
		tag = option.optarg

	if option.option == 'c'
		cmd = option.optarg

	if option.option == 's'
		serial = true

if tag == "" or cmd == ""
	console.log "Hi."
	console.log "This is how you use and abuse me:"
	console.log " runon -t deploy_tag=erlang_prod -c \"ls -alh /\""
	process.exit(1)
	return # lol

tag_bits = tag.split '='

if tag_bits[1] == undefined
	console.log "'sup?"
	console.log "When you define tags, they need to be in the following format:"
	console.log " tag_name=tag_value"
	process.exit(1)
	return # lol

console.log "Okay! Running \"#{cmd}\" on all instances that match the following tag: #{tag}"

ec2.describeInstances {Filters: [{Name: "tag:#{tag_bits[0]}", Values: [tag_bits[1]]}]}, (err, data) ->
	if err or not data or not data.Reservations
		console.log "Whoops. There was an error getting the instance list from Amazon. Here's the error:"
		console.dir err
		process.exit 1
		return # lol

	instance_list = []
	for reservation in data.Reservations
		for instance in reservation.Instances
			instance_list.push instance

	if instance_list.length <= 0
		console.log "I didn't find any instances that have the tag #{tag}, check your tag key/value?"
		process.exit 1
		return # lol

	acmd = async.each
	if serial
		acmd = async.eachSeries

	acmd instance_list, ((instance, cb) =>
		instance_name = itag.Value for itag in instance.Tags when itag.Key == 'Name'
		resp = spawn 'ssh', ["#{config.ssh_user}@" + instance.PrivateIpAddress, cmd]
		resp.stdout.on 'data', (data) ->
			console.log "#{instance_name}: #{data}"
		resp.stderr.on 'data', (data) ->
			console.log "#{instance_name}: #{data}"
		resp.on 'close', (data) ->
			console.log "Job's done on #{instance.PrivateIpAddress} (#{instance_name})"
			cb()
		), ((err) ->
		)