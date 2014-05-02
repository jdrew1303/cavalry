assert = require 'assert'
path = require 'path'
rimraf = require 'rimraf'
fs = require 'fs'
testpath = path.resolve '.', 'testrepos'
opts =
  deploydir: path.join testpath, 'deploy'
  repodir: path.join testpath, 'repos'
gitter = require('../lib/gitter.coffee') opts
Stream = require('stream').Stream

describe "gitter", ->

  after (done) ->
    @timeout 10000
    rimraf opts.repodir, ->
    rimraf opts.deploydir, ->
      done()

  it 'should be a Stream', ->
    assert gitter instanceof Stream
  it 'should fetch a repo without error', (done) ->
    @timeout 10000
    gitter.fetch "test1", "https://github.com/davidbanham/test1.git", (err) ->
      done err

  it 'should return an error for an unreachable repo', (done) ->
    @timeout 10000
    gitter.fetch "phantom", "http://example.com/thisrepodoesnotexistnotevenalittlebit", (err) ->
      assert.notEqual err, null
      done()
  describe 'opt checking', ->
    it 'should bail if name is missing', (done) ->
      gitter.deploy
        commit: '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
        pid: Math.floor(Math.random() * (1 << 24)).toString(16)
      , (err, tookaction) ->
        done assert.deepEqual err, new Error 'Insufficient args'
    it 'should bail if pid is missing', (done) ->
      gitter.deploy
        commit: '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
        name: 'test1'
      , (err, tookaction) ->
        done assert.deepEqual err, new Error 'Insufficient args'
    it 'should bail if commit is missing', (done) ->
      gitter.deploy
        pid: Math.floor(Math.random() * (1 << 24)).toString(16)
        name: 'test1'
      , (err, tookaction) ->
        done assert.deepEqual err, new Error 'Insufficient args'

  it 'should deploy a repo without error', (done) ->
    @timeout 10000
    gitter.fetch "test1", "https://github.com/davidbanham/test1.git", (err) ->
      gitter.deploy
        name: 'test1'
        commit: '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
        pid: Math.floor(Math.random() * (1 << 24)).toString(16)
      , (err, tookaction) ->
        assert.equal null, err
        assert tookaction
        done err

  it 'should fail gracefully with an unreachable repo', (done) ->
    gitter.deploy
      name: 'foo'
      commit: '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
      pid: Math.floor(Math.random() * (1 << 24)).toString(16)
    , (err, tookaction) ->
      assert.notEqual null, err
      assert err.message.indexOf 'Failed connect to' > -1
      done()

  it 'should deploy the repo to the correct dir', (done) ->
    name = 'test1'
    commit = '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
    pid = Math.floor(Math.random() * (1 << 24)).toString(16)
    gitter.deploy
      name: name
      commit: commit
      pid: pid
    , (err, tookaction) ->
      assert.equal null, err
      assert tookaction
      fs.exists path.join(opts.deploydir, "#{name}.#{pid}.#{commit}"), (exists) ->
        assert exists
        done()

  it 'should deploy all files in a repo', (done) ->
    name = 'test1'
    commit = '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
    pid = Math.floor(Math.random() * (1 << 24)).toString(16)
    gitter.deploy
      name: name
      commit: commit
      pid: pid
    , (err, tookaction) ->
      assert.deepEqual ['.git', 'server.js'], fs.readdirSync path.join opts.deploydir, "#{name}.#{pid}.#{commit}"
      assert.equal null, err
      assert tookaction
      done err

  #it 'should perform under load', (done) ->
  #  @timeout 100000
  #  completed = 0
  #  iterations = [1..500]
  #  for i in iterations
  #    do ->
  #      name = 'test1'
  #      commit = '7bc4bbc44cf9ce4daa7dee4187a11759a51c3447'
  #      pid = Math.floor(Math.random() * (1 << 24)).toString(16)
  #      gitter.deploy
  #        name: name
  #        commit: commit
  #        pid: pid
  #      , (err, tookaction) ->
  #        fs.readdir path.join(opts.deploydir, "#{name}.#{pid}.#{commit}"), (err, files) ->
  #          assert.deepEqual ['.git', 'server.js'], files
  #          assert.equal null, err
  #          assert tookaction
  #          completed++
  #          done() if completed is iterations.length
