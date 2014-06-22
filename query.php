<?php

#!/bin/bash
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

function query ($query) {
    global $dbc;
    $stmt = $dbc->prepare ($query);
    if (!$stmt)
        throw new Exception ('Cannot create prepared statement: ' . $dbc->error);

    if (func_num_args() > 1) {
        $arg_string = func_get_arg (1);
        $arg_values = array_slice (func_get_args(), 2);
        while (!is_array ($arg_values) || !is_array ($arg_values [0])) {
            $arg_values = array ($arg_values);
        };
        if (is_array ($arg_values [0] [0])) {
            $arg_values = $arg_values [0];
        };

        $params = array();
        $bind_args = array ($arg_string);
        for ($i = 0; $i < strlen ($arg_string); $i ++) {
            $params [$i] = null;
            $bind_args[] =& $params [$i];
        };
        if (!call_user_func_array (array ($stmt, 'bind_param'), $bind_args))
            throw new Exception ('Cannot bind arguments to the prepared statement: ' . $stmt->error);

        foreach ($arg_values as $arg_set) {
            foreach ($arg_set as $i => $v) {
                $params [$i] = $v;
            };
            if (!$stmt->execute())
                throw new Exception ('Cannot execute prepared statement: ' . $stmt->error);
        };
    } else {
        if (!$stmt->execute())
            throw new Exception ('Cannot execute prepared statement: ' . $stmt->error);
    };

    if ($metadata = $stmt->result_metadata()) {
        $stmt->store_result();
        $bind_args = $res = $row = array();
        while ($field = $metadata->fetch_field()) {
            $bind_args[] =& $row [$field->name];
        };
        call_user_func_array (array ($stmt, 'bind_result'), $bind_args);

        while ($stmt->fetch()) {
            $row_to =& $res[];
            $row_to = array();
            foreach ($row as $k => $v) {
                $row_to [$k] = $v;
            };
        };
    } else {
        $res = null;
    };

    return $res;
};

?>