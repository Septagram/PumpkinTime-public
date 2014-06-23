<?php

# Copyright (c) 2013, Igor Novikov
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

global $config;
$app = new Slim\Slim (array (
    'debug' => $config ['debug'],
));

// We probably should do the following with the middleware, but I don't really see the motivation to add extra syntactic sugar:
foreach (array (
    'Access-Control-Allow-Origin'       => 'http://' . $config ['domain'],
    'Access-Control-Allow-Credentials'  => 'true',
    'Access-Control-Allow-Headers'      => $app->request->headers->get ('Access-Control-Request-Headers'),
    'Access-Control-Expose-Headers'     => 'Content-Type',
    'Content-Type'                      => 'application/json',
) as $name => $value) {
    $app->response->headers->set ($name, $value);
};

function json_api ($is_auth_required, $callback = null) {
    $app = Slim\Slim::getInstance();
    if (!isset ($callback)) {
        $callback = $is_auth_required;
        $is_auth_required = false;
    };
    return function() use ($app, $callback, $is_auth_required) {
        global $config;
        $args = func_get_args();
        try {
            if ($app->request->isPost()) {
                $body = json_decode ($app->request->getBody(), true);
                if (json_last_error() !== JSON_ERROR_NONE)
                    throw new Pumxeption (400, 'bad_json', 'invalid request body, please use JSON');
                $args[] = $body;
            };
            if ($is_auth_required && session ('account_id') === null)
                throw new Pumxeption (401, 'no_auth', 'you must be logged in to access this functionality');
            $res = call_user_func_array ($callback, $args);
        } catch (Exception $error) {
            $e = $error;
            if (!is_a ($e, 'Pumxeption')) {
                if ($config ['logging']) {
                    error_log ($config ['logging'] === 1 ? $e->getMessage() : $e->__toString());
                };
                $e = new Pumxeption (500, 'fail', 'internal error, please contact administrator');
            };
            $res = array (
                'error' => array (
                    'id'            => $e->id,
                    'code'          => $e->code,
                    'description'   => $e->getMessage(),
                ),
            );
            $app->response->setStatus ($e->code);
        };
        $app->response->setBody (json_encode ($res));
    };
};

$app->options ('/.*?', function() use ($app) {
    $app->response->headers->set ('Content-Type', null);
});

$app->get ('/hello', json_api (function() {
    return 'hello world';
}));

?>