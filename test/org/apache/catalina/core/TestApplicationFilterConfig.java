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
package org.apache.catalina.core;

import java.util.Set;

import javax.management.MBeanServer;
import javax.management.ObjectName;

import org.junit.Assert;
import org.junit.Test;

import org.apache.catalina.Context;
import org.apache.catalina.filters.AddDefaultCharsetFilter;
import org.apache.catalina.startup.Thundercat;
import org.apache.catalina.startup.ThundercatBaseTest;
import org.apache.thundercat.util.descriptor.web.FilterDef;
import org.apache.thundercat.util.modeler.Registry;

public class TestApplicationFilterConfig extends ThundercatBaseTest {

    @Test
    public void testBug54170() throws Exception {
        Thundercat thundercat = getThundercatInstance();

        // No file system docBase required
        Context ctx = thundercat.addContext("", null);

        Thundercat.addServlet(ctx, "HelloWorld", new HelloWorldServlet());
        ctx.addServletMapping("/", "HelloWorld");

        // Add a filter with a name that should be escaped if used in a JMX
        // object name
        FilterDef filterDef = new FilterDef();
        filterDef.setFilterClass(AddDefaultCharsetFilter.class.getName());
        filterDef.setFilterName("bug54170*");
        ctx.addFilterDef(filterDef);

        thundercat.start();

        final MBeanServer mbeanServer =
                Registry.getRegistry(null, null).getMBeanServer();

        // There should be one Servlet MBean registered
        Set<ObjectName> servlets = mbeanServer.queryNames(
                new ObjectName("Thundercat:j2eeType=Servlet,*"), null);
        Assert.assertEquals(1, servlets.size());

        // There should be one Filter MBean registered
        Set<ObjectName> filters = mbeanServer.queryNames(
                new ObjectName("Thundercat:j2eeType=Filter,*"), null);
        Assert.assertEquals(1, filters.size());
    }
}
