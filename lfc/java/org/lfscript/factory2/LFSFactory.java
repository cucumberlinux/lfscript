/*
 * - LFSFactory.java -
 *
 * Copyright (c) 2011-2017 Marcel van den Boer
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */

package org.lfscript.factory2;

import java.io.IOException; /* FIXME: Factory should not perform I/O */

import nl.marcelweb.util.Pair;

import java.util.Set;
import java.util.List;

public class LFSFactory extends XMLFactory {
    private final BuildBase buildbase;

    @Override
    public void configureBlacklist(final Set<String> blacklist) {
        blacklist.add("hostreqs.xml");
        blacklist.add("typography.xml");
        blacklist.add("creatingfilesystem.xml");
        blacklist.add("mounting.xml");
        blacklist.add("introduction.xml");
        blacklist.add("aboutlfs.xml");
        blacklist.add("aboutsbus.xml");
        blacklist.add("toolchaintechnotes.xml");
        blacklist.add("generalinstructions.xml");
        blacklist.add("pkgmgt.xml");
        blacklist.add("strippingagain.xml");
        blacklist.add("network.xml");
        blacklist.add("hosts.xml");
        blacklist.add("symlinks.xml");
        blacklist.add("usage.xml");
        blacklist.add("hostname.xml");
        blacklist.add("setclock.xml");
        blacklist.add("console.xml");
        blacklist.add("profile.xml");
        blacklist.add("inputrc.xml");
        blacklist.add("fstab.xml");
        blacklist.add("etcshells.xml");
        blacklist.add("chapter07/sysklogd.xml");
        blacklist.add("chapter08/grub.xml");
    }

    public LFSFactory(final String book, final String revision) {
        super(book, revision);

        this.buildbase = new BuildBase();
    }

    @Override
    public void buildAll(final String target, final boolean withHeader,
            final boolean withGroups) throws IOException {

        /* Build and write scripts */
        super.buildAll(target, withHeader, withGroups);

        /* Write out 'buildbase.lfs' */
        this.buildbase.writeOut(target + "/buildbase.lfs", withHeader,
                this.getEntities());
    }

    @Override
    protected Script parseXML(final String pack, String xml)
            throws IOException {

        /* Remove unselected revision from section tags */
        xml = XMLFactory.sanitizeXML(xml);

        final Script script = super.parseXML(pack, xml);

        if (script == null) {
            this.buildbase.addSection(pack, xml, this.getEntities());
        } else {
            this.parseLfsDependencies(xml, script);
            this.buildbase.addBuild(script.getName());

            /* Add instruction to refresh bash */
            if (!pack.startsWith(this.book + "chapter05/")
                        && script.getName().equals("bash")) {
                this.buildbase.addCommand("# (Refresh bash)");
                this.buildbase.addCommand("exec /bin/bash --login +h");
            }
        }

        return script;
    }

    @Override
    protected void parseBuild(final String path, final String section,
            final Script script) {
        if (path.startsWith(this.book + "chapter05/")) {

            /* Toolchain */
            final List<Pair<String, String>> commands
                    = SemiXML.innerXML(section, "userinput",
                        " remap=\"pre\"",
                        " remap=\"configure\"",
                        " remap=\"make\"",
                        " remap=\"install\"",
                        " remap=\"adjust\"");

            for (final Pair<String, String> command : commands) {
                    script.putPreparation(
                            SemiXML.asText(command.getA(), this.getEntities()),
                                    path.endsWith("-pass2.xml"));
            }
        } else {

            /* Final system */
            final String installArg = " remap=\"install\"";
            final String localeArg = " remap=\"locale-full\"";

            final List<Pair<String, String>> commands = SemiXML.innerXML(
                    section, "userinput",
                           " remap=\"pre\"",
                           " remap=\"configure\"",
                           " remap=\"make\"",
                            localeArg, installArg);

            for (final Pair<String, String> command : commands) {
                if (command.getB() == installArg
                        || command.getB() == localeArg) {
                    script.putInstallation(SemiXML.asText(command.getA(),
                            this.getEntities()));
                } else {
                    script.putCompilation(SemiXML.asText(command.getA(),
                            this.getEntities()));
                }
            }
        }
    }

    private void parseLfsDependencies(final String xml, final Script script) {

        /* LFS: Add primary source */
        String url = this.getEntities().get("&" + script.getName() + "-url;");
        String md5 = this.getEntities().get("&" + script.getName() + "-md5;");

        if (url == null || md5 == null) {
            final String pName = SemiXML.innerXML(SemiXML.innerXML(xml,
                "sect1info", " condition=\"script\"").get(0).getA(),
                "productname", "").get(0).getA();

            url = this.getEntities().get("&" + pName + "-url;");
            md5 = this.getEntities().get("&" + pName + "-md5;");
        }
        if (url == null || md5 == null) {
            throw new RuntimeException("Primary source or MD5 for "
                    + script.getName() + " not found.");
        }

        script.setPrimarySource(url, md5);

        /* LFS: Add secondary source code to scripts */
        final String pRoot = this.getEntities().get("&patches-root;");
        final Set<String> files = script.usedFiles();
        for (final String file : files) {
            final Set<String> entKeys = this.getEntities().keySet();
            for (final String entKey : entKeys) {
                final String value = this.getEntities().get(entKey);

                if (value.endsWith(file)) {
                    if (entKey.endsWith("-url;")) {
                        script.addSource(value, this.getEntities().get(
                                entKey.substring(0, entKey.length() - 5)
                                        + "-md5;"));
                    } else if (entKey.endsWith("-patch;")) {
                        script.addSource(pRoot + value, this.getEntities().get(
                                entKey.substring(0, entKey.length() - 1)
                                        + "-md5;"));
                    }
                }
            }
        }
    }
}
