/*
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Java member jump-to-definition support (the `geiser:java-symbol-location'
 * procedure).  Given the same (code-string, cursor-index) a completion request
 * uses, this resolves the Java member at point to its owning class and the
 * precise source line(s) of every overload with that name.
 *
 * "Which class" is reused from kawa-devutil's completion machinery
 * (CompletionForClassMember.getOwnerClass()).  "Which line" is read from the
 * compiled class's LineNumberTable via `javap -l' (the JDK that runs Kawa ships
 * javap; jumps are interactive and infrequent, so a per-jump subprocess is
 * fine).  Overloads are returned as separate matches keyed by their human
 * signature, so the Elisp side can offer a chooser and land on the exact line.
 */
package kawageiser;

import gnu.kawa.functions.Format;
import gnu.lists.IString;
import gnu.lists.LList;
import gnu.math.IntNum;
import kawadevutil.complete.find.CompletionFindGeneric;
import kawadevutil.complete.result.abstractdata.CompletionData;
import kawadevutil.complete.result.abstractdata.CompletionForClassMember;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.security.CodeSource;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class GeiserJavaLocation {

    // A 2-space-indented javap method/constructor declaration line, e.g.
    //   "  public static java.lang.String format(java.lang.String, ...);"
    // Capture group 1 = the member name (the identifier just before '(').
    private static final Pattern METHOD_DECL =
            Pattern.compile("^ {2}\\S.*?\\b(\\w+)\\(.*\\);?\\s*$");
    // A LineNumberTable entry, e.g. "      line 2961: 0".
    private static final Pattern LINE_ENTRY =
            Pattern.compile("^ {4,}line (\\d+):");

    /**
     * Geiser procedure entry point.  Returns a readable Lisp form (read on the
     * Elisp side with `read-from-string'):
     *
     *   (("matches"
     *     ((("member" "format")
     *       ("signature" "public static java.lang.String format(...)")
     *       ("source-resource" "java/lang/String.java")
     *       ("line" 2961))
     *      ...))
     *    ("class" "java.lang.String"))
     *
     * `matches' is empty when the symbol at point is not a resolvable Java
     * member access.
     */
    public static String locate(IString codeStr, IntNum cursorIndex) throws Throwable {
        List<Object> matches = new ArrayList<>();
        String className = "";

        Optional<CompletionData> cd =
                CompletionFindGeneric.find(codeStr.toString(), cursorIndex.intValue());

        if (cd.isPresent() && cd.get() instanceof CompletionForClassMember) {
            CompletionForClassMember cm = (CompletionForClassMember) cd.get();
            Class<?> owner = cm.getOwnerClass();
            className = owner.getName();
            String member = cm.getCursorFinder().getCursorMatch().getBeforeCursor();
            String resource = sourceResourceOf(owner);
            for (MethodLine ml : javapMethodLines(owner)) {
                if (!member.isEmpty() && !ml.name.equals(member)) {
                    continue;
                }
                matches.add(LList.makeList(Arrays.asList(
                        LList.list2("member", ml.name),
                        LList.list2("signature", ml.signature),
                        LList.list2("source-resource", resource),
                        LList.list2("line", IntNum.valueOf(ml.line)))));
            }
        }

        LList result = LList.makeList(Arrays.asList(
                LList.list2("matches", LList.makeList(matches)),
                LList.list2("class", className)));
        return Format.format("~S", result).toString();
    }

    /** Top-level-class source path, e.g. "net/minecraft/util/MathHelper.java". */
    private static String sourceResourceOf(Class<?> owner) {
        String binary = owner.getName();          // e.g. "pkg.Outer$Inner"
        int dollar = binary.indexOf('$');
        String topLevel = dollar >= 0 ? binary.substring(0, dollar) : binary;
        return topLevel.replace('.', '/') + ".java";
    }

    private static final class MethodLine {
        final String name;
        final String signature;
        final int line;
        MethodLine(String name, String signature, int line) {
            this.name = name;
            this.signature = signature;
            this.line = line;
        }
    }

    /**
     * Run `javap -l' on OWNER and return one MethodLine per method/constructor
     * that has a LineNumberTable (its first source line).  Methods without line
     * info (e.g. abstract/native) and fields are skipped.
     */
    private static List<MethodLine> javapMethodLines(Class<?> owner) throws Exception {
        List<String> cmd = new ArrayList<>(Arrays.asList("javap", "-l"));
        CodeSource cs = owner.getProtectionDomain().getCodeSource();
        if (cs != null && cs.getLocation() != null) {
            // App / Minecraft classes: tell javap which jar/dir to read.
            cmd.add("-classpath");
            cmd.add(new File(cs.getLocation().toURI()).getPath());
        }
        // Bootstrap JDK classes have a null CodeSource; javap finds them anyway.
        cmd.add(owner.getName());

        ProcessBuilder pb = new ProcessBuilder(cmd);
        pb.redirectErrorStream(true);
        Process proc = pb.start();

        List<MethodLine> out = new ArrayList<>();
        String pendingName = null;
        String pendingSig = null;
        boolean lineTaken = false;
        try (BufferedReader r = new BufferedReader(
                new InputStreamReader(proc.getInputStream()))) {
            String raw;
            while ((raw = r.readLine()) != null) {
                Matcher md = METHOD_DECL.matcher(raw);
                if (md.matches()) {
                    pendingName = md.group(1);
                    pendingSig = raw.trim().replaceAll(";\\s*$", "");
                    lineTaken = false;
                    continue;
                }
                if (pendingName != null && !lineTaken) {
                    Matcher le = LINE_ENTRY.matcher(raw);
                    if (le.find()) {
                        out.add(new MethodLine(pendingName, pendingSig,
                                Integer.parseInt(le.group(1))));
                        lineTaken = true;
                    }
                }
            }
        }
        proc.waitFor();
        return out;
    }
}
