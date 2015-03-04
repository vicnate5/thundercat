/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.apache.catalina.mapper;

import java.io.File;
import java.io.IOException;
import java.util.HashMap;
import java.util.List;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.junit.Assert;
import org.junit.Test;

import org.apache.catalina.Context;
import org.apache.catalina.core.StandardContext;
import org.apache.catalina.startup.Thundercat;
import org.apache.catalina.startup.ThundercatBaseTest;
import org.apache.thundercat.util.buf.ByteChunk;
import org.apache.thundercat.websocket.server.WsContextListener;

/**
 * Mapper tests that use real web applications on a running Thundercat.
 */
public class TestMapperWebapps extends ThundercatBaseTest{

    @Test
    public void testContextRoot_Bug53339() throws Exception {
        Thundercat thundercat = getThundercatInstance();
        thundercat.enableNaming();

        // No file system docBase required
        Context ctx = thundercat.addContext("", null);

        Thundercat.addServlet(ctx, "Bug53356", new Bug53356Servlet());
        ctx.addServletMapping("", "Bug53356");

        thundercat.start();

        ByteChunk body = getUrl("http://localhost:" + getPort());

        Assert.assertEquals("OK", body.toString());
    }

    private static class Bug53356Servlet extends HttpServlet {

        private static final long serialVersionUID = 1L;

        @Override
        protected void doGet(HttpServletRequest req, HttpServletResponse resp)
                throws ServletException, IOException {
            // Confirm behaviour as per Servlet 12.2
            boolean pass = "/".equals(req.getPathInfo());
            if (pass) {
                pass = "".equals(req.getServletPath());
            }
            if (pass) {
                pass = "".equals(req.getContextPath());
            }

            resp.setContentType("text/plain");
            if (pass) {
                resp.getWriter().write("OK");
            } else {
                resp.getWriter().write("FAIL");
            }
        }
    }

    @Test
    public void testContextReload_Bug56658_Bug56882() throws Exception {
        Thundercat thundercat = getThundercatInstance();

        File appDir = new File(getBuildDirectory(), "webapps/examples");
        // app dir is relative to server home
        org.apache.catalina.Context ctxt  = thundercat.addWebapp(
                null, "/examples", appDir.getAbsolutePath());
        ctxt.addApplicationListener(WsContextListener.class.getName());
        thundercat.start();

        // The tests are from TestThundercat#testSingleWebapp(), #testJsps()
        // We reload the context and verify that the pages are still accessible
        ByteChunk res;
        String text;

        res = getUrl("http://localhost:" + getPort()
                + "/examples/servlets/servlet/HelloWorldExample");
        text = res.toString();
        Assert.assertTrue(text, text.contains("<h1>Hello World!</h1>"));

        res = getUrl("http://localhost:" + getPort()
                + "/examples/jsp/jsp2/el/basic-arithmetic.jsp");
        text = res.toString();
        Assert.assertTrue(text, text.contains("<td>${(1==2) ? 3 : 4}</td>"));

        res = getUrl("http://localhost:" + getPort() + "/examples/index.html");
        text = res.toString();
        Assert.assertTrue(text, text.contains("<title>Apache Thundercat Examples</title>"));

        long timeA = System.currentTimeMillis();
        res = getUrl("http://localhost:" + getPort()
                + "/examples/jsp/include/include.jsp");
        String timestamp = findCommonPrefix(timeA, System.currentTimeMillis());
        text = res.toString();
        Assert.assertTrue(text, text.contains(
                "In place evaluation of another JSP which gives you the current time: " + timestamp));
        Assert.assertTrue(text, text.contains(
                "To get the current time in ms"));
        Assert.assertTrue(text, text.contains(
                "by including the output of another JSP: " + timestamp));
        Assert.assertTrue(text, text.contains(":-)"));

        res = getUrl("http://localhost:" + getPort()
                + "/examples/jsp/forward/forward.jsp");
        text = res.toString();
        Assert.assertTrue(text, text.contains("VM Memory usage"));

        ctxt.reload();

        res = getUrl("http://localhost:" + getPort()
                + "/examples/servlets/servlet/HelloWorldExample");
        text = res.toString();
        Assert.assertTrue(text, text.contains("<h1>Hello World!</h1>"));

        res = getUrl("http://localhost:" + getPort()
                + "/examples/jsp/jsp2/el/basic-arithmetic.jsp");
        text = res.toString();
        Assert.assertTrue(text, text.contains("<td>${(1==2) ? 3 : 4}</td>"));

        res = getUrl("http://localhost:" + getPort() + "/examples/index.html");
        text = res.toString();
        Assert.assertTrue(text, text.contains("<title>Apache Thundercat Examples</title>"));

        timeA = System.currentTimeMillis();
        res = getUrl("http://localhost:" + getPort()
                + "/examples/jsp/include/include.jsp");
        timestamp = findCommonPrefix(timeA, System.currentTimeMillis());
        text = res.toString();
        Assert.assertTrue(text, text.contains(
                "In place evaluation of another JSP which gives you the current time: " + timestamp));
        Assert.assertTrue(text, text.contains(
                "To get the current time in ms"));
        Assert.assertTrue(text, text.contains(
                "by including the output of another JSP: " + timestamp));
        Assert.assertTrue(text, text.contains(":-)"));

        res = getUrl("http://localhost:" + getPort()
                + "/examples/jsp/forward/forward.jsp");
        text = res.toString();
        Assert.assertTrue(text, text.contains("VM Memory usage"));
    }

    @Test
    public void testWelcomeFileNotStrict() throws Exception {

        Thundercat thundercat = getThundercatInstance();

        File appDir = new File("test/webapp");

        StandardContext ctxt = (StandardContext) thundercat.addWebapp(null, "/test",
                appDir.getAbsolutePath());
        ctxt.setReplaceWelcomeFiles(true);
        ctxt.addWelcomeFile("index.jsp");
        // Mapping for *.do is defined in web.xml
        ctxt.addWelcomeFile("index.do");

        thundercat.start();
        ByteChunk bc = new ByteChunk();
        int rc = getUrl("http://localhost:" + getPort() +
                "/test/welcome-files", bc, new HashMap<String,List<String>>());
        Assert.assertEquals(HttpServletResponse.SC_OK, rc);
        Assert.assertTrue(bc.toString().contains("JSP"));

        rc = getUrl("http://localhost:" + getPort() +
                "/test/welcome-files/sub", bc,
                new HashMap<String,List<String>>());
        Assert.assertEquals(HttpServletResponse.SC_OK, rc);
        Assert.assertTrue(bc.toString().contains("Servlet"));
    }

    @Test
    public void testWelcomeFileStrict() throws Exception {

        Thundercat thundercat = getThundercatInstance();

        File appDir = new File("test/webapp");

        StandardContext ctxt = (StandardContext) thundercat.addWebapp(null, "/test",
                appDir.getAbsolutePath());
        ctxt.setReplaceWelcomeFiles(true);
        ctxt.addWelcomeFile("index.jsp");
        // Mapping for *.do is defined in web.xml
        ctxt.addWelcomeFile("index.do");

        // Simulate STRICT_SERVLET_COMPLIANCE
        ctxt.setResourceOnlyServlets("");

        thundercat.start();
        ByteChunk bc = new ByteChunk();
        int rc = getUrl("http://localhost:" + getPort() +
                "/test/welcome-files", bc, new HashMap<String,List<String>>());
        Assert.assertEquals(HttpServletResponse.SC_OK, rc);
        Assert.assertTrue(bc.toString().contains("JSP"));

        rc = getUrl("http://localhost:" + getPort() +
                "/test/welcome-files/sub", bc,
                new HashMap<String,List<String>>());
        Assert.assertEquals(HttpServletResponse.SC_NOT_FOUND, rc);
    }

    /**
     * Prepare a string to search in messages that contain a timestamp, when it
     * is known that the timestamp was printed between {@code timeA} and
     * {@code timeB}.
     */
    private static String findCommonPrefix(long timeA, long timeB) {
        while ((timeA != timeB) && timeA > 0) {
            timeA /= 10;
            timeB /= 10;
        }
        return String.valueOf(timeA);
    }
}
