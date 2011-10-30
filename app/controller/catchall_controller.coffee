url = require "url"
request = require "request"

{ TimeoutError } = require "../../lib/error"
{ Controller } = require "../controller"

class CatchAll extends Controller
  path: ( ) -> "*"

  middleware: -> [ @api, @apiKey ]

  execute: ( req, res, next ) ->
    { pathname } = url.parse req.url

    model = @gatekeeper.model "apiLimits"

    { qps, qpd, key } = req.apiKey

    model.withinLimits key, { qps, qpd }, ( err, [ currentQps, currentQpd ] ) =>
      return next err if err

      model.apiHit key, ( err, [ newQps, newQpd ] ) =>
        return next err if err

        # copy the headers
        headers = req.headers
        delete headers.host

        options =
          url: "http://#{ req.api.endpoint }/#{ pathname }"
          followRedirects: true
          maxRedirects: req.api.maxRedirects
          timeout: req.api.endpointTimeout
          headers: headers

        # add a body for PUTs and POSTs
        options.body = req.body if req.body?

        request[ @constructor.verb ] options, ( err, apiRes, body ) ->
          # if we timeout then throw an error
          if err?.code is "ETIMEDOUT"
            return next new TimeoutError "API endpoint timed out."

          # copy headers from the endpoint
          for header, value of apiRes.headers
            res.header header, value

          # response with the same code as the endpoint
          res.send body, apiRes.statusCode

class exports.GetController extends CatchAll
  @verb: "get"

class exports.PostController extends CatchAll
  @verb: "post"

class exports.PutController extends CatchAll
  @verb: "put"

class exports.DeleteController extends CatchAll
  @verb: "delete"