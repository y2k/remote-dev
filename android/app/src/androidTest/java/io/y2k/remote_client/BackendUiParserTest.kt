package io.y2k.remote_client

import android.graphics.Bitmap
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.test.ExperimentalTestApi
import androidx.compose.ui.test.assertTextContains
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performKeyInput
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import java.io.ByteArrayOutputStream
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
@OptIn(ExperimentalTestApi::class)
class BackendUiParserTest {
    @get:Rule val composeRule = createComposeRule()

    @Test
    fun parsesTextRowsEventsAndInputsAndRejectsUnsupportedDocuments() {
        assertEquals(
            UiNode.Column(
                listOf(
                    UiNode.Text("Worktrees"),
                    UiNode.Row(
                        listOf(
                            UiNode.Button("OK"),
                            UiNode.Button("New", UiEvent("[\"New\"]")),
                            UiNode.Input("Input", UiEvent("[\"Input\"]")),
                        )
                    ),
                )
            ),
            parseUiNode(
                """{"@type":"column","children":[{"@type":"text","text":"Worktrees"},{"@type":"row","children":[{"@type":"button","label":"OK"},{"@type":"button","label":"New","event":["New"]},{"@type":"input","label":"Input","event":["Input"]}]}]}"""
            ),
        )

        val worktreeButton =
            parseUiNode(
                """{"@type":"button","label":"Worktree","event":["Worktrees_msg",["Select","/tmp/clicked"]]}"""
            )
                as UiNode.Button
        assertEquals("Worktree", worktreeButton.label)
        assertEquals(
            "/tmp/clicked",
            JSONArray(requireNotNull(worktreeButton.event).json).getJSONArray(1).getString(1),
        )

        assertEquals(
            UiNode.Input("Input", UiEvent("[\"Input\"]"), "draft"),
            parseUiNode("""{"@type":"input","label":"Input","event":["Input"],"text":"draft"}"""),
        )
        assertEquals(
            UiNode.Row(listOf(UiNode.Text("Left"), UiNode.Text("Right")), listOf(2f, 1f)),
            parseUiNode(
                """{"@type":"row","children":[{"@type":"text","text":"Left"},{"@type":"text","text":"Right"}],"weights":[2,1]}"""
            ),
        )
        assertEquals(
            UiNode.Image("/emulators/emulator-5554/screenshot.png", "Pixel"),
            parseUiNode(
                """{"@type":"image","src":"/emulators/emulator-5554/screenshot.png","label":"Pixel"}"""
            ),
        )

        listOf(
                """{"@type":"text"}""",
                """{"@type":"text","text":1}""",
                """{"@type":"row"}""",
                """{"@type":"row","children":{}}""",
                """{"@type":"row","children":["bad"]}""",
                """{"@type":"row","children":[],"weights":{}}""",
                """{"@type":"row","children":[{"@type":"text","text":"Left"},{"@type":"text","text":"Right"}],"weights":[1]}""",
                """{"@type":"row","children":[{"@type":"text","text":"Left"},{"@type":"text","text":"Right"}],"weights":[1,"bad"]}""",
                """{"@type":"row","children":[{"@type":"text","text":"Left"},{"@type":"text","text":"Right"}],"weights":[1,0]}""",
                """{"@type":"button","label":"Event","event":"not-an-object"}""",
                """{"@type":"input","event":{"type":"input"}}""",
                """{"@type":"input","label":1,"event":{"type":"input"}}""",
                """{"@type":"input","label":"Input"}""",
                """{"@type":"input","label":"Input","event":"not-an-object"}""",
                """{"@type":"input","label":"Input","event":{"type":"input"},"text":1}""",
                """{"@type":"image","label":"Pixel"}""",
                """{"@type":"image","src":1,"label":"Pixel"}""",
                """{"@type":"image","src":"https://example.com/screenshot.png","label":"Pixel"}""",
                """{"@type":"image","src":"//example.com/screenshot.png","label":"Pixel"}""",
                """{"@type":"image","src":"/emulators/5554.png","label":1}""",
            )
            .forEach { json ->
                try {
                    parseUiNode(json)
                    fail("Unsupported document was accepted: $json")
                } catch (_: Exception) {}
            }
    }

    @Test
    fun buildsEventRequestEnvelope() {
        val request =
            JSONObject(
                eventRequest(UiEvent("[\"Worktree_msg\",[\"Run_prompt\",\"__VALUE__\"]]"), "draft")
            )

        assertEquals(
            "Run_prompt",
            request.getJSONArray("event").getJSONArray(1).getString(0),
        )
        assertEquals("draft", request.getString("value"))
        assertEquals(
            true,
            JSONObject(eventRequest(UiEvent("[\"Worktrees_msg\",[\"Load\"]]"), null))
                .isNull("value"),
        )
        assertEquals(
            true,
            JSONObject(eventRequest(UiEvent("[\"Worktrees_msg\",[\"Load\"]]"), null)).has("value"),
        )
    }

    @Test
    fun replacesDisplayedDocumentForEachStreamedLine() {
        val documents =
            listOf(
                    """{"@type":"text","text":"Hel"}""",
                    """{"@type":"text","text":"Hello"}""",
                )
                .map(::parseUiNode)
        var node by mutableStateOf(documents.first())
        composeRule.setContent { UiNodeContent(node, {}, { _, _ -> }, false) }

        documents.forEach { document ->
            composeRule.runOnIdle { node = document }
            composeRule
                .onNodeWithText((document as UiNode.Text).text)
                .assertTextContains(document.text)
        }
    }

    @Test
    fun inputSubmitsItsValueOnHardwareEnter() {
        var submitted: Pair<UiEvent, String>? = null
        composeRule.setContent {
            UiNodeContent(
                UiNode.Input("Input", UiEvent("[\"Input\"]")),
                {},
                { event, value -> submitted = event to value },
                false,
            )
        }

        composeRule.onNodeWithTag("input").performTextInput("draft")
        composeRule.onNodeWithTag("input").performKeyInput {
            keyDown(Key.Enter)
            keyUp(Key.Enter)
        }

        composeRule.runOnIdle {
            assertEquals(UiEvent("[\"Input\"]") to "draft", submitted)
        }
    }

    @Test
    fun buttonSubmitsItsEvent() {
        var submitted: UiEvent? = null
        composeRule.setContent {
            UiNodeContent(
                UiNode.Button("Worktree", UiEvent("[\"Select\"]")),
                { event -> submitted = event },
                { _, _ -> },
                false,
            )
        }

        composeRule.onNodeWithText("Worktree").performClick()

        composeRule.runOnIdle {
            assertEquals(UiEvent("[\"Select\"]"), submitted)
        }
    }

    @Test
    fun inputBlocksDuplicateEnterWhileSubmitting() {
        var calls = 0
        var inProgress by mutableStateOf(false)
        composeRule.setContent {
            UiNodeContent(
                UiNode.Input("Input", UiEvent("[\"Input\"]")),
                {},
                { _, _ ->
                    calls++
                    inProgress = true
                },
                inProgress,
            )
        }

        composeRule.onNodeWithTag("input").performClick()
        composeRule.onNodeWithTag("input").performKeyInput {
            keyDown(Key.Enter)
            keyUp(Key.Enter)
        }
        composeRule.onNodeWithTag("input").performKeyInput {
            keyDown(Key.Enter)
            keyUp(Key.Enter)
        }

        composeRule.runOnIdle { assertEquals(1, calls) }
    }

    @Test
    fun inputAcceptsAnEventAfterStreamCompletion() {
        var calls = 0
        var inProgress by mutableStateOf(true)
        composeRule.setContent {
            UiNodeContent(
                UiNode.Input("Input", UiEvent("[\"Input\"]")),
                {},
                { _, _ -> calls++ },
                inProgress,
            )
        }

        composeRule.runOnIdle { inProgress = false }
        composeRule.onNodeWithTag("input").performClick()
        composeRule.onNodeWithTag("input").performKeyInput {
            keyDown(Key.Enter)
            keyUp(Key.Enter)
        }

        composeRule.runOnIdle { assertEquals(1, calls) }
    }

    @Test
    fun inputKeepsDraftWhenSubmissionEndsWithoutReplacement() {
        var inProgress by mutableStateOf(false)
        composeRule.setContent {
            UiNodeContent(
                parseUiNode(
                    """{"@type":"input","label":"Input","event":["Input"],"text":"seed"}"""
                ),
                {},
                { _, _ -> },
                inProgress,
            )
        }

        composeRule.onNodeWithTag("input").assertTextContains("seed")
        composeRule.onNodeWithTag("input").performTextInput("-draft")
        composeRule.runOnIdle { inProgress = true }
        composeRule.runOnIdle { inProgress = false }

        composeRule.onNodeWithTag("input").assertTextContains("-draftseed")
    }

    @Test
    fun inputUsesTextFromReplacementDocument() {
        var node by mutableStateOf<UiNode>(UiNode.Input("Input", UiEvent("[\"Input\"]"), "seed"))
        composeRule.setContent {
            UiNodeContent(node, {}, { _, _ -> }, false)
        }

        composeRule.onNodeWithTag("input").performTextInput("-draft")
        composeRule.runOnIdle {
            node = UiNode.Input("Input", UiEvent("[\"Input\"]"), "returned")
        }

        composeRule.onNodeWithTag("input").assertTextContains("returned")
    }

    @Test
    fun decodesPng() {
        val bytes =
            ByteArrayOutputStream().use { output ->
                Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
                    .compress(
                        Bitmap.CompressFormat.PNG,
                        100,
                        output,
                    )
                output.toByteArray()
            }

        assertEquals(1, decodePng(bytes).width)
    }

    @Test
    fun imageRendersAndKeepsSurroundingContentOnFailure() {
        composeRule.setContent {
            UiNodeContent(
                UiNode.Column(
                    listOf(
                        UiNode.Text("Still here"),
                        UiNode.Image("/emulators/emulator-5554/screenshot.png", "Pixel"),
                    )
                ),
                {},
                { _, _ -> },
                false,
                loadImage = { throw IllegalStateException("unavailable") },
            )
        }

        composeRule.onNodeWithText("Still here").assertTextContains("Still here")
        composeRule.onNodeWithText("Error: Pixel").assertTextContains("Error: Pixel")
    }

    @Test
    fun weightedRowUsesProportionalWidths() {
        composeRule.setContent {
            UiNodeContent(
                UiNode.Row(
                    listOf(UiNode.Image("/left.png", "Left"), UiNode.Image("/right.png", "Right")),
                    listOf(2f, 1f),
                ),
                {},
                { _, _ -> },
                false,
                loadImage = { ImageBitmap(1, 1) },
            )
        }

        val left =
            composeRule.onNodeWithContentDescription("Left").fetchSemanticsNode().boundsInRoot.width
        val right =
            composeRule
                .onNodeWithContentDescription("Right")
                .fetchSemanticsNode()
                .boundsInRoot
                .width
        assertEquals(2f, left / right, 0.01f)
    }

    @Test
    fun imageRefreshesWithoutSubmittingAnEvent() {
        var requests = 0
        var events = 0
        composeRule.setContent {
            UiNodeContent(
                UiNode.Image("/emulators/emulator-5554/screenshot.png", "Pixel"),
                { events++ },
                { _, _ -> events++ },
                false,
                loadImage = {
                    requests++
                    ImageBitmap(1, 1)
                },
            )
        }

        composeRule.onNodeWithTag("image").fetchSemanticsNode()
        composeRule.waitUntil(4_000) { requests >= 2 }
        assertEquals(0, events)
    }
}
