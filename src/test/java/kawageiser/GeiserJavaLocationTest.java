/*
 * SPDX-License-Identifier: BSD-3-Clause
 */
package kawageiser;

import gnu.expr.Language;
import gnu.lists.IString;
import gnu.math.IntNum;
import kawa.standard.Scheme;
import org.testng.annotations.Test;

import static org.testng.Assert.assertTrue;

public class GeiserJavaLocationTest {

    @Test
    public void testLocateStringFormatMembers() throws Throwable {
        Scheme scheme = new Scheme();
        Language saveLang = Language.setSaveCurrent(scheme);
        try {
            // "(java.lang.String:format)" — cursor (index 24) right after the
            // member name "format", before the closing paren.
            String result = GeiserJavaLocation.locate(
                    IString.valueOf("(java.lang.String:format)"),
                    IntNum.valueOf(24));

            // Resolves the owning class and the source file path for it.
            assertTrue(result.contains("java/lang/String.java"),
                    "expected source-resource java/lang/String.java in: " + result);
            // Returns the member name and at least one concrete line number
            // from the LineNumberTable (String.format lives well past line 100).
            assertTrue(result.contains("format"),
                    "expected member 'format' in: " + result);
            assertTrue(result.matches("(?s).*\\(.?line.? [1-9][0-9]{2,}.*"),
                    "expected a plausible source line (>=100) in: " + result);
        } finally {
            Language.restoreCurrent(saveLang);
        }
    }
}
