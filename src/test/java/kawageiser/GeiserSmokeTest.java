/*
 * SPDX-License-Identifier: BSD-3-Clause
 */
package kawageiser;

import gnu.expr.Language;
import gnu.lists.IString;
import gnu.math.IntNum;
import gnu.mapping.Environment;
import kawa.standard.Scheme;
import kawageiser.kawadevutil.Complete;
import org.testng.annotations.Test;

import static org.testng.Assert.assertTrue;

public class GeiserSmokeTest {
    @Test
    public void testJavaMemberCompletionContainsFormat() throws Throwable {
        // completeJava needs a current Language; set up a Scheme like the
        // autodoc test does.
        Scheme scheme = new Scheme();
        Language saveLang = Language.setSaveCurrent(scheme);
        try {
            // "(java.lang.String:)" — index 18 is right after the ':'.
            String result = Complete.completeJava(
                    IString.valueOf("(java.lang.String:)"),
                    IntNum.valueOf(18));
            assertTrue(result.contains("format"),
                    "expected a java.lang.String member 'format' in: " + result);
        } finally {
            Language.restoreCurrent(saveLang);
        }
    }
}
