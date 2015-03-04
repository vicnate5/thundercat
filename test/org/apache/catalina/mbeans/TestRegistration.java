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
package org.apache.catalina.mbeans;

import java.io.File;
import java.net.InetAddress;
import java.net.UnknownHostException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Set;

import javax.management.MBeanServer;
import javax.management.MalformedObjectNameException;
import javax.management.ObjectName;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import org.junit.Assert;
import org.junit.Test;

import org.apache.catalina.Context;
import org.apache.catalina.Realm;
import org.apache.catalina.core.StandardHost;
import org.apache.catalina.realm.CombinedRealm;
import org.apache.catalina.realm.NullRealm;
import org.apache.catalina.startup.Thundercat;
import org.apache.catalina.startup.ThundercatBaseTest;
import org.apache.thundercat.util.modeler.Registry;

/**
 * General tests around the process of registration and de-registration that
 * don't necessarily apply to one specific Thundercat class.
 *
 */
public class TestRegistration extends ThundercatBaseTest {

    private static final String contextName = "/foo";

    private static final String ADDRESS;

    static {
        String address;
        try {
            address = InetAddress.getByName("localhost").getHostAddress();
        } catch (UnknownHostException e) {
            address = "INIT_FAILED";
        }
        ADDRESS = address;
    }


    private static String[] basicMBeanNames() {
        return new String[] {
            "Thundercat:type=Engine",
            "Thundercat:type=Realm,realmPath=/realm0",
            "Thundercat:type=Mapper",
            "Thundercat:type=MBeanFactory",
            "Thundercat:type=NamingResources",
            "Thundercat:type=Server",
            "Thundercat:type=Service",
            "Thundercat:type=StringCache",
            "Thundercat:type=Valve,name=StandardEngineValve",
        };
    }

    private static String[] hostMBeanNames(String host) {
        return new String[] {
            "Thundercat:type=Host,host=" + host,
            "Thundercat:type=Valve,host=" + host + ",name=ErrorReportValve",
            "Thundercat:type=Valve,host=" + host + ",name=StandardHostValve",
        };
    }

    private String[] optionalMBeanNames(String host) {
        if (isAccessLogEnabled()) {
            return new String[] {
                "Thundercat:type=Valve,host=" + host + ",name=AccessLogValve",
            };
        } else {
            return new String[] { };
        }
    }

    private static String[] requestMBeanNames(String port, String type) {
        return new String[] {
            "Thundercat:type=RequestProcessor,worker=" +
                    ObjectName.quote("http-" + type + "-" + ADDRESS + "-" + port) +
                    ",name=HttpRequest1",
        };
    }

    private static String[] contextMBeanNames(String host, String context) {
        return new String[] {
            "Thundercat:j2eeType=WebModule,name=//" + host + context +
                ",J2EEApplication=none,J2EEServer=none",
            "Thundercat:type=Loader,host=" + host + ",context=" + context,
            "Thundercat:type=Manager,host=" + host + ",context=" + context,
            "Thundercat:type=NamingResources,host=" + host + ",context=" + context,
            "Thundercat:type=Valve,host=" + host + ",context=" + context +
                    ",name=NonLoginAuthenticator",
            "Thundercat:type=Valve,host=" + host + ",context=" + context +
                    ",name=StandardContextValve",
            "Thundercat:type=WebappClassLoader,host=" + host + ",context=" + context,
            "Thundercat:type=WebResourceRoot,host=" + host + ",context=" + context,
            "Thundercat:type=WebResourceRoot,host=" + host + ",context=" + context +
                    ",name=Cache",
            "Thundercat:type=Realm,realmPath=/realm0,host=" + host +
            ",context=" + context,
            "Thundercat:type=Realm,realmPath=/realm0/realm0,host=" + host +
            ",context=" + context
        };
    }

    private static String[] connectorMBeanNames(String port, String type) {
        return new String[] {
        "Thundercat:type=Connector,port=" + port + ",address="
                + ObjectName.quote(ADDRESS),
        "Thundercat:type=GlobalRequestProcessor,name="
                + ObjectName.quote("http-" + type + "-" + ADDRESS + "-" + port),
        "Thundercat:type=ProtocolHandler,port=" + port + ",address="
                + ObjectName.quote(ADDRESS),
        "Thundercat:type=ThreadPool,name="
                + ObjectName.quote("http-" + type + "-" + ADDRESS + "-" + port),
        };
    }

    /*
     * Test verifying that Thundercat correctly de-registers the MBeans it has
     * registered.
     * @author Marc Guillemot
     */
    @Test
    public void testMBeanDeregistration() throws Exception {
        final MBeanServer mbeanServer = Registry.getRegistry(null, null).getMBeanServer();
        // Verify there are no Catalina or Thundercat MBeans
        Set<ObjectName> onames = mbeanServer.queryNames(new ObjectName("Catalina:*"), null);
        log.info(MBeanDumper.dumpBeans(mbeanServer, onames));
        assertEquals("Unexpected: " + onames, 0, onames.size());
        onames = mbeanServer.queryNames(new ObjectName("Thundercat:*"), null);
        log.info(MBeanDumper.dumpBeans(mbeanServer, onames));
        assertEquals("Unexpected: " + onames, 0, onames.size());

        final Thundercat thundercat = getThundercatInstance();
        final File contextDir = new File(getTemporaryDirectory(), "webappFoo");
        addDeleteOnTearDown(contextDir);
        if (!contextDir.mkdirs() && !contextDir.isDirectory()) {
            fail("Failed to create: [" + contextDir.toString() + "]");
        }
        Context ctx = thundercat.addContext(contextName, contextDir.getAbsolutePath());

        CombinedRealm combinedRealm = new CombinedRealm();
        Realm nullRealm = new NullRealm();
        combinedRealm.addRealm(nullRealm);
        ctx.setRealm(combinedRealm);

        thundercat.start();

        getUrl("http://localhost:" + getPort());

        // Verify there are no Catalina MBeans
        onames = mbeanServer.queryNames(new ObjectName("Catalina:*"), null);
        log.info(MBeanDumper.dumpBeans(mbeanServer, onames));
        assertEquals("Found: " + onames, 0, onames.size());

        // Verify there are the correct Thundercat MBeans
        onames = mbeanServer.queryNames(new ObjectName("Thundercat:*"), null);
        ArrayList<String> found = new ArrayList<>(onames.size());
        for (ObjectName on: onames) {
            found.add(on.toString());
        }

        // Create the list of expected MBean names
        String protocol = thundercat.getConnector().getProtocolHandlerClassName();
        if (protocol.indexOf("Nio2") > 0) {
            protocol = "nio2";
        } else if (protocol.indexOf("Apr") > 0) {
            protocol = "apr";
        } else {
            protocol = "nio";
        }
        String index = thundercat.getConnector().getProperty("nameIndex").toString();
        ArrayList<String> expected = new ArrayList<>(Arrays.asList(basicMBeanNames()));
        expected.addAll(Arrays.asList(hostMBeanNames("localhost")));
        expected.addAll(Arrays.asList(contextMBeanNames("localhost", contextName)));
        expected.addAll(Arrays.asList(connectorMBeanNames("auto-" + index, protocol)));
        expected.addAll(Arrays.asList(optionalMBeanNames("localhost")));
        expected.addAll(Arrays.asList(requestMBeanNames(
                "auto-" + index + "-" + getPort(), protocol)));

        // Did we find all expected MBeans?
        ArrayList<String> missing = new ArrayList<>(expected);
        missing.removeAll(found);
        assertTrue("Missing Thundercat MBeans: " + missing, missing.isEmpty());

        // Did we find any unexpected MBeans?
        List<String> additional = found;
        additional.removeAll(expected);
        assertTrue("Unexpected Thundercat MBeans: " + additional, additional.isEmpty());

        thundercat.stop();

        // There should still be some Thundercat MBeans
        onames = mbeanServer.queryNames(new ObjectName("Thundercat:*"), null);
        assertTrue("No Thundercat MBeans", onames.size() > 0);

        // add a new host
        StandardHost host = new StandardHost();
        host.setName("otherhost");
        thundercat.getEngine().addChild(host);

        final File contextDir2 = new File(getTemporaryDirectory(), "webappFoo2");
        addDeleteOnTearDown(contextDir2);
        if (!contextDir2.mkdirs() && !contextDir2.isDirectory()) {
            fail("Failed to create: [" + contextDir2.toString() + "]");
        }
        thundercat.addContext(host, contextName + "2", contextDir2.getAbsolutePath());

        thundercat.start();
        thundercat.stop();
        thundercat.destroy();

        // There should be no Catalina MBeans and no Thundercat MBeans
        onames = mbeanServer.queryNames(new ObjectName("Catalina:*"), null);
        log.info(MBeanDumper.dumpBeans(mbeanServer, onames));
        assertEquals("Remaining: " + onames, 0, onames.size());
        onames = mbeanServer.queryNames(new ObjectName("Thundercat:*"), null);
        log.info(MBeanDumper.dumpBeans(mbeanServer, onames));
        assertEquals("Remaining: " + onames, 0, onames.size());
    }

    /*
     * Confirm that, as far as ObjectName is concerned, the order of the key
     * properties is not significant.
     */
    @Test
    public void testNames() throws MalformedObjectNameException {
        ObjectName on1 = new ObjectName("test:foo=a,bar=b");
        ObjectName on2 = new ObjectName("test:bar=b,foo=a");

        Assert.assertTrue(on1.equals(on2));
    }
}
