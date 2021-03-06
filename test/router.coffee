assert = require 'assert'
fs = require 'fs'
path = require 'path'
router = require '../lib/router.coffee'
describe 'routes', ->
  before (done) ->
    if router.nginx? and router.nginx.stdout?
      done()
    else
      router.once 'ready', ->
        #router.nginx.stdout.on 'data', (buf) ->
        #  console.log buf.toString()
        #router.nginx.stderr.on 'data', (buf) ->
        #  console.log buf.toString()
        #router.nginx.on 'exit', (code, signal) ->
        #  console.log "nginx exited", code, signal
        #router.nginx.on 'error', (err) ->
        #  console.log "nginx err", err
        done()
  after (done) ->
    router.takedown()
    router.nginx.once 'exit', ->
      done()
  routingTable =
    repo1:
      domain: 'repo1.example.com'
      routes: [
        {
          host: 'slave1.example.com'
          port: 8000
        }
        {
          host: 'slave2.example.com'
          port: 8001
        }
      ]
    repo2:
      domain: 'repo2.example.com'
      method: 'ip_hash'
      routes: [
        {
          host: 'slave1.example.com'
          port: 8001
        }
      ]
    repo3:
      domain: 'repo3.example.com'
      routes: [
        {
          host: 'slave2.example.com'
          port: 8000
        }
      ]
  it "Should build the mustache options object correctly", ->
    options = router.buildOpts routingTable
    assert.deepEqual options.server,
      [
        { domain: 'repo1.example.com', name: 'repo1', directives: [], location_arguments: [], client_max_body_size: '1m', maintenance: undefined }
        { domain: 'repo2.example.com', name: 'repo2', directives: [], location_arguments: [], client_max_body_size: '1m', maintenance: undefined }
        { domain: 'repo3.example.com', name: 'repo3', directives: [], location_arguments: [], client_max_body_size: '1m', maintenance: undefined }
      ]
    assert.deepEqual options.upstream,
      [
        {
          name: 'repo1', method: 'least_conn', routes: [
            { host: 'slave1.example.com', port: 8000 }
            { host: 'slave2.example.com', port: 8001 }
          ]
        }
        {
          name: 'repo2', method: 'ip_hash', routes: [
            { host: 'slave1.example.com', port: 8001 }
          ]
        }
        {
          name: 'repo3', method: 'least_conn', routes: [
            { host: 'slave2.example.com', port: 8000 }
          ]
        }
      ]
  it "Should include the routing directives in the template", (done) ->
    localRoutingTable =
      repo1:
        domain: 'repo1.example.com'
        method: 'ip_hash'
        directives: [
          "real_ip_header X-Forwarded-For"
        ]
        routes: [
          {
            host: 'slave1.example.com'
            port: 8000
          }
        ]
    options = router.buildOpts localRoutingTable
    assert.deepEqual options.server,
      [
        { domain: 'repo1.example.com', name: 'repo1', directives: [
          {directive: "real_ip_header X-Forwarded-For"}
        ], location_arguments: [], client_max_body_size: '1m', maintenance: undefined}
      ]
    done()
  it "Should include the location arguments in the template", (done) ->
    localRoutingTable =
      repo1:
        domain: 'repo1.example.com'
        method: 'ip_hash'
        location_arguments: [
          "proxy_buffering off"
        ]
        routes: [
          {
            host: 'slave1.example.com'
            port: 8000
          }
        ]
    options = router.buildOpts localRoutingTable
    assert.deepEqual options.server,
      [
        { domain: 'repo1.example.com', name: 'repo1', directives: [], location_arguments: [
          {argument: "proxy_buffering off"}
        ], client_max_body_size: '1m', maintenance: undefined}
      ]
    done()
  it "Should render the template without throwing an error", (done) ->
    router.writeFile routingTable, (err) ->
      assert.equal null, err
      done()
  it "Should spawn an nginx process on start", (done) ->
    assert router.nginx.stdout?
    done()
  it "Should write an nginx pidfile", (done) ->
    setTimeout ->
      assert fs.existsSync(path.join router.pidpath, "nginx.pid"), "pidfile does not exist"
      assert.equal fs.readFileSync(path.join router.pidpath, "nginx.pid").toString(), router.nginx.pid, "pid in file does not match process"
      done()
    , 50
  it "Shouldn't write the same routing table twice", (done) ->
    router.currentHash = undefined
    router.writeFile routingTable, (err, action) ->
      assert.equal err, null
      assert.equal action, true
      router.writeFile routingTable, (err, action) ->
        assert.equal err, null
        assert.equal action, false
        done()
