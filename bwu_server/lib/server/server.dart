library bwu_server.server.server;

import 'dart:async' as async;
import 'dart:convert' show JSON;
import 'dart:io' as io;

import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:http_server/http_server.dart' as ht;

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as sIo;
import 'package:shelf_exception_response/exception_response.dart' as sEx;
import 'package:shelf_auth/shelf_auth.dart' as sAuth;
import 'package:shelf_route/shelf_route.dart' as sRoute;
import 'package:option/option.dart';

import 'package:tentacle_response_formatter/formatter.dart' as tf;

import 'package:logging/logging.dart' show Logger;

part 'shelf.dart';

final _log = new Logger('bwu_server.server.server');
final _logShelf = new Logger('bwu_server.shelf');


class BwuServer {

  final servePort;

  final io.Directory webRoot;


  BwuServer(this.servePort, this.webRoot);

  async.Future<bool> init() {

    return initAuthenticateOnDatastore()
    .then((success) {

      final sessionHandler = new sAuth.JwtSessionHandler('bwu_server.bwu-dart.com',
      '8zyaXDX1LfJD', null);

      final sessionMiddleware = sAuth.authenticate([],
      sessionHandler: sessionHandler,
      allowHttp: true,
      allowAnonymousAccess: false);

      final x = new shelf.Cascade();

      final router = (sRoute.router()
        ..post('/anonymous', _handleAnonymousRequest)
        ..post('/login', _handleLoginRequest)
        ..post('/authenticated', _handleHttpRequest, middleware: sessionMiddleware)
        ..post('/service', _handleServiceHttpRequest, middleware: sessionMiddleware)
      );

      var handler = const shelf.Pipeline()
      .addMiddleware(shelf.logRequests(logger:
          (String msg, bool isError) =>
              isError ?
              _logShelf.severe(msg) :
              _logShelf.info(msg)))
      .addMiddleware(_responseHeadersMiddleware)
      .addMiddleware(_errorResponse)
      .addHandler(router.handler);

      sRoute.printRoutes(router);
      return sIo.serve(handler, '0.0.0.0', servePort).then((server) {
        server.autoCompress = true;
        server.defaultResponseHeaders.chunkedTransferEncoding = true;
        _log.finest('Serving at http://${server.address.host}:${server.port}');
        return true;
      });
    });
  }

  async.Future<auth.AccessCredentials> initAuthenticateOnDatastore() {
    return auth.obtainAccessCredentialsViaServiceAccount(
        new auth.ServiceAccountCredentials(null,
        null, null),
        null, new http.Client());
  }


  async.Future<shelf.Response> _handleAnonymousRequest(shelf.Request request) {
    _log.finest('Request for "${request.url}"');
    return request.readAsString()
    .then((String messageString) {
      return null;
    });
  }

  async.Future<shelf.Response> _handleLoginRequest(shelf.Request request) {
    Option<sAuth.AuthenticatedContext> context = sAuth.getAuthenticatedContext(request);

    return new async.Future.value(null);
  }

  async.Future<shelf.Response> _handleHttpRequest(shelf.Request request) {
    Option<sAuth.AuthenticatedContext> context = sAuth.getAuthenticatedContext(request);


    _log.finest('Request for "${request.url}"');
    return request.readAsString()
    .then((String messageString) {

      throw 'Unknow request: ${messageString}.';
    });
  }


  async.Future<shelf.Response> _handleServiceHttpRequest(shelf.Request request) {
    Option<sAuth.AuthenticatedContext> context = sAuth.getAuthenticatedContext(request);


    _log.finest('Request for "${request.url}"');
    return request.readAsString()
    .then((String messageString) {
      throw 'Unknow service request: ${messageString}.';
    });
  }


  void _handleWebSocketConnect(webSocket) {
    _log.finest('WebSocket connect.');
    webSocket.listen((message) {
      _log.finest('WebSocket request: $message.');
      webSocket.add("echo $message");
      Map json = JSON.decode(message);

      throw 'not implemented.';
    });
  }

  void _serve(io.HttpServer server) {
    ht.VirtualDirectory vd = new ht.VirtualDirectory(webRoot.path);
    server.listen((request) {
      print('request');
      if (io.WebSocketTransformer.isUpgradeRequest(request)) {
        io.WebSocketTransformer.upgrade(request).then(_handleWebsocket);
      } else {
        print("Regular ${request.method} for: uri: ${request.uri}, conn localport: ${request.connectionInfo.localPort} remote: ${request.connectionInfo.remoteAddress} port: ${request.connectionInfo.remotePort}");
        if (request.uri.path == '/') {
          request.response
            ..redirect(Uri.parse('/index.html'), status: io.HttpStatus.MOVED_PERMANENTLY)
            ..close();
        } else {
          vd.serveRequest(request);
        }
      }
    });
  }

  final _connectedClients = <io.WebSocket>[];

  void _handleWebsocket(io.WebSocket socket) {
    print('Client connected');
    _connectedClients.add(socket);

    socket.listen((String s) {
      print('Client sent: $s');
    },
    onDone: () {
      _connectedClients.remove(socket);
      print('Client disconnected');
    });
  }

  void addService(String name) {
  }

  void removeService(String name) {
  }
}
