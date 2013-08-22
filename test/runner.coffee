assert = require 'assert'
fs = require 'fs'
path = require 'path'
rimraf = require 'rimraf'
testpath = path.resolve '.', 'testrepos'
deploydir = path.join testpath, 'deploy'
slave = require('../lib/runner.coffee')
slave.deploydir = deploydir
describe 'slave', ->
  before (done) ->
    fs.mkdir testpath, ->
    fs.mkdir deploydir, ->
    fs.symlink path.join(testpath, "test1.7bc4bbc44cf9ce4daa7dee4187a11759a51c3447"), path.join(testpath, "deploy", "test1.7bc4bbc44cf9ce4daa7dee4187a11759a51c3447"), ->
      done()
  after (done) ->
    rimraf deploydir, ->
      done()
  it 'should have a processes object', ->
    assert slave.processes
  it 'should have a spawn method', ->
    assert slave.spawn
  it 'should spawn a process in the right directory', (done) ->
    rand = Math.floor(Math.random() * (1 << 24)).toString(16)
    opts =
      repo: 'test1'
      commit: '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
      command: ['touch', rand]
      once: true
    slave.spawn opts, (proc) ->
      assert proc.status, "running"
      assert proc.repo, "test1"
      assert proc.commit, '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
      setTimeout ->
        touchedFile = path.join deploydir, proc.repo+'.'+proc.commit, rand
        assert fs.existsSync touchedFile
        fs.unlinkSync touchedFile
        done()
      , 5

describe 'process', ->
  before (done) ->
    fs.mkdir testpath, ->
    fs.mkdir deploydir, ->
    return done() if process.env.TRAVIS
    fs.mkdir path.join(deploydir, 'test1.7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'), (err) ->
      assert.equal err, null, "Error creating test directory #{err}"
      done()
  after (done) ->
    rimraf deploydir, ->
      done()

  it 'should pass back stdout properly', (done) ->
    return done() if process.env.TRAVIS
    rand = Math.floor(Math.random() * (1 << 24)).toString(16)
    opts =
      repo: 'test1'
      commit: '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
      command: ['node', '-e', "console.log('#{rand}');"]
      once: true
    slave.spawn opts
    slave.on 'stdout', (buf) ->
      str = buf.toString().replace(/(\r\n|\n|\r)/gm,"") #Strip the line feed.
      done() if str is rand

  it 'should respawn the process when it dies', (done) ->
    return done() if process.env.TRAVIS
    rand = Math.floor(Math.random() * (1 << 24)).toString(16)
    opts =
      repo: 'test1'
      commit: '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
      command: ['node', '-e', "console.log('#{rand}');"]
      debounce: 1
    pid = null
    slave.spawn opts, (proc) ->
      pid = proc.id
    count = 0
    slave.on 'stdout', (buf) ->
      str = buf.toString().replace(/(\r\n|\n|\r)/gm,"") #Strip the line feed.
      count++ if str is rand
      slave.removeAllListeners() if count is 2
      done() if count is 2
      slave.stop pid if count is 2

  it 'should stop the process when told', (done) ->
    return done() if process.env.TRAVIS
    rand = Math.floor(Math.random() * (1 << 24)).toString(16)
    opts =
      repo: 'test1'
      commit: '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
      command: ['node', '-e', "console.log('#{rand}');"]
      debounce: 1
    slave.spawn opts, (proc) ->
      slave.on 'stop', (info) ->
        done() if info.id is proc.id
      slave.stop proc.id
      slave.on 'stdout', (buf, info) ->
        assert.notEqual proc.id, info.id

  it 'should stop a range of ids', (done) ->
    return done() if process.env.TRAVIS
    rand = Math.floor(Math.random() * (1 << 24)).toString(16)
    rand2 = Math.floor(Math.random() * (1 << 24)).toString(16)
    opts =
      repo: 'test1'
      commit: '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
      command: ['node', '-e', "console.log('#{rand}');"]
      debounce: 1
    opts2 =
      repo: 'test1'
      commit: '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
      command: ['node', '-e', "console.log('#{rand2}');"]
      debounce: 1
    pids = []
    count = 0
    slave.spawn opts, (proc) ->
      pids.push proc.id
    slave.spawn opts2, (proc) ->
      pids.push proc.id
      slave.on 'stop', (info) ->
        count++ if info.id is pid for pid in pids
        done() if count is pids.length
      slave.stop pids
      slave.on 'stdout', (buf, info) ->
        assert.notEqual proc.id, info.id
  it 'should restart the process when told', (done) ->
    return done() if process.env.TRAVIS
    rand = Math.floor(Math.random() * (1 << 24)).toString(16)
    opts =
      repo: 'test1'
      commit: '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
      command: ['node', 'server.js']
      debounce: 1
    slave.spawn opts, (proc) ->
      slave.on 'exit', (code, signal, info) ->
        slave.stop proc.id if info.id is proc.id
        done() if info.id is proc.id
      slave.restart proc.id
