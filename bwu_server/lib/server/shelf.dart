part of bwu_server.server.server;

const Map<String,String> _responseHeaders = const <String,String>{
    io.HttpHeaders.CONTENT_TYPE: "application/json",
    "Access-Control-Allow-Origin": "http://localhost:63342",
    "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
    //"Access-Control-Allow-Credentials": "true", // only for auth cookies
    "Access-Control-Allow-Headers": "Origin, X-Requested-With, Content-Type, Accept, Authorization",
    "Access-Control-Expose-Headers": "Authorization"
};

/// Add CORS headers to all requests.
/// If the request is an OPTIONS request just return with the set headers.
shelf.Middleware _responseHeadersMiddleware = shelf.createMiddleware(

    requestHandler: ((shelf.Request request) =>
    (request.method == 'OPTIONS') ?
    new shelf.Response.ok(null, headers: _responseHeaders): null),

    responseHandler: ((shelf.Response response) =>
        response.change(headers: _responseHeaders)));


final shelf.Middleware _errorResponse = (shelf.Handler handler) {
  tf.ResponseFormatter formatter = new tf.ResponseFormatter();
  return (shelf.Request request) {
    return new async.Future.sync(() => handler(request))
    .then((response) => response)
    .catchError((error, stackTrace) {
      _log.severe(error);
      _log.severe(stackTrace);
      if(request.headers['content-type'] == 'application/json') {
        var responseMessage;
        int status = io.HttpStatus.INTERNAL_SERVER_ERROR;
        if(error is String) {
          responseMessage = "";
        } else if(error is sEx.HttpException) {
          final e = error as sEx.HttpException;
          responseMessage = "";
          status = e.status;
        } else if(error == null) {
          responseMessage = error;
        } else if(error is NoSuchMethodError) {
          //responseMessage = new msg.ErrorResponse()..message = 'Authentication failed.';
          status = io.HttpStatus.UNAUTHORIZED;
        }
        return new shelf.Response(status,
        body: "",
        headers: {
            'content-type': 'application/json'
        });
      } else {
        tf.FormatResult result = formatter.formatResponse(request, error.toMap());
        return new shelf.Response(error.status, body: result.body,
        headers: {io.HttpHeaders.CONTENT_TYPE:result.contentType});
      }
    }, test: (e) =>
    e is String || e == null|| e is sEx.HttpException || e is NoSuchMethodError);
  };
};
