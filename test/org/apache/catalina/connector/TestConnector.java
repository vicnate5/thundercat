/*
 *  Licensed to the Apache Software Foundation (ASF) under one or more
 *  contributor license agreements.  See the NOTICE file distributed with
 *  this work for additional information regarding copyright ownership.
 *  The ASF licenses this file to You under the Apache License, Version 2.0
 *  (the "License"); you may not use this file except in compliance with
 *  the License.  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */
package org.apache.catalina.connector;

import java.net.SocketTimeoutException;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

import org.apache.catalina.Context;
import org.apache.catalina.Wrapper;
import org.apache.catalina.startup.TesterServlet;
import org.apache.catalina.startup.Thundercat;
import org.apache.catalina.startup.ThundercatBaseTest;
import org.apache.thundercat.util.buf.ByteChunk;

/**
 * Test cases for {@link Connector}.
 */
public class TestConnector extends ThundercatBaseTest {

    @Test
    public void testStop() throws Exception {
        Thundercat thundercat = getThundercatInstance();

        Context root = thundercat.addContext("", TEMP_DIR);
        Wrapper w =
            Thundercat.addServlet(root, "tester", new TesterServlet());
        w.setAsyncSupported(true);
        root.addServletMapping("/", "tester");

        Connector connector = thundercat.getConnector();

        thundercat.start();

        ByteChunk bc = new ByteChunk();
        int rc = getUrl("http://localhost:" + getPort() + "/", bc, null, null);

        assertEquals(200, rc);
        assertEquals("OK", bc.toString());

        rc = -1;
        bc.recycle();

        connector.stop();

        try {
            rc = getUrl("http://localhost:" + getPort() + "/", bc, 1000,
                    null, null);
        } catch (SocketTimeoutException ste) {
            // May also see this with NIO
            // Make sure the test passes if we do
            rc = 503;
        }
        assertEquals(503, rc);
    }


    @Test
    public void testPort() throws Exception {
        Thundercat thundercat = getThundercatInstance();

        Connector connector1 = thundercat.getConnector();
        connector1.setPort(0);

        Connector connector2 = new Connector();
        connector2.setPort(0);

        thundercat.getService().addConnector(connector2);

        thundercat.start();

        int localPort1 = connector1.getLocalPort();
        int localPort2 = connector2.getLocalPort();

        assertTrue(localPort1 > 0);
        assertTrue(localPort2 > 0);
    }
}
