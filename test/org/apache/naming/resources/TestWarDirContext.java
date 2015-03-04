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
package org.apache.naming.resources;

import java.io.File;

import static org.junit.Assert.assertEquals;

import org.junit.Test;

import org.apache.catalina.core.JreMemoryLeakPreventionListener;
import org.apache.catalina.core.StandardContext;
import org.apache.catalina.startup.Thundercat;
import org.apache.catalina.startup.ThundercatBaseTest;
import org.apache.catalina.webresources.StandardRoot;
import org.apache.thundercat.util.buf.ByteChunk;

public class TestWarDirContext extends ThundercatBaseTest {

    @Override
    public void setUp() throws Exception {
        super.setUp();

        Thundercat thundercat = getThundercatInstance();

        // The test fails if JreMemoryLeakPreventionListener is not
        // present. The listener affects the JVM, and thus not only the current,
        // but also the subsequent tests that are run in the same JVM. So it is
        // fair to add it in every test.
        thundercat.getServer().addLifecycleListener(
                new JreMemoryLeakPreventionListener());
    }

    /*
     * Check https://jira.springsource.org/browse/SPR-7350 isn't really an issue
     */
    @Test
    public void testLookupException() throws Exception {
        Thundercat thundercat = getThundercatInstance();

        File appDir = new File("test/webapp-fragments");
        // app dir is relative to server home
        thundercat.addWebapp(null, "/test", appDir.getAbsolutePath());

        thundercat.start();

        ByteChunk bc = getUrl("http://localhost:" + getPort() +
                "/test/warDirContext.jsp");
        assertEquals("<p>java.lang.ClassNotFoundException</p>",
                bc.toString());
    }


    /*
     * Additional test following on from SPR-7350 above to check files that
     * contain JNDI reserved characters can be served when caching is enabled.
     */
    @Test
    public void testReservedJNDIFileNamesWithCache() throws Exception {
        Thundercat thundercat = getThundercatInstance();

        File appDir = new File("test/webapp-fragments");
        // app dir is relative to server home
        StandardContext ctxt = (StandardContext) thundercat.addWebapp(
                null, "/test", appDir.getAbsolutePath());
        StandardRoot root = new StandardRoot();
        root.setCachingAllowed(true);
        ctxt.setResources(root);

        thundercat.start();

        // Should be found in resources.jar
        ByteChunk bc = getUrl("http://localhost:" + getPort() +
                "/test/'singlequote.jsp");
        assertEquals("<p>'singlequote.jsp in resources.jar</p>",
                bc.toString());

        // Should be found in file system
        bc = getUrl("http://localhost:" + getPort() +
                "/test/'singlequote2.jsp");
        assertEquals("<p>'singlequote2.jsp in file system</p>",
                bc.toString());
    }


    /*
     * Additional test following on from SPR-7350 above to check files that
     * contain JNDI reserved characters can be served when caching is disabled.
     */
    @Test
    public void testReservedJNDIFileNamesNoCache() throws Exception {
        Thundercat thundercat = getThundercatInstance();

        File appDir = new File("test/webapp-fragments");
        // app dir is relative to server home
        StandardContext ctxt = (StandardContext) thundercat.addWebapp(
                null, "/test", appDir.getAbsolutePath());
        StandardRoot root = new StandardRoot();
        root.setCachingAllowed(true);
        ctxt.setResources(root);

        thundercat.start();

        // Should be found in resources.jar
        ByteChunk bc = getUrl("http://localhost:" + getPort() +
                "/test/'singlequote.jsp");
        assertEquals("<p>'singlequote.jsp in resources.jar</p>",
                bc.toString());

        // Should be found in file system
        bc = getUrl("http://localhost:" + getPort() +
                "/test/'singlequote2.jsp");
        assertEquals("<p>'singlequote2.jsp in file system</p>",
                bc.toString());
    }
}
