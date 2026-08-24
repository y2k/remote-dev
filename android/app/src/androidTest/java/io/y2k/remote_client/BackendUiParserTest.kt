package io.y2k.remote_client

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.test.assertTextContains
import androidx.compose.ui.test.ExperimentalTestApi
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performKeyInput
import androidx.compose.ui.test.performTextInput
import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.json.JSONObject

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
                            UiNode.Button("New", UiEvent("{\"type\":\"new\"}")),
                            UiNode.Input("Input", UiEvent("{\"type\":\"input\"}")),
                        ),
                    ),
                ),
            ),
            parseUiNode(
                """{"@type":"column","children":[{"@type":"text","text":"Worktrees"},{"@type":"row","children":[{"@type":"button","label":"OK"},{"@type":"button","label":"New","event":{"type":"new"}},{"@type":"input","label":"Input","event":{"type":"input"}}]}]}""",
            ),
        )

        val worktreeButton =
            parseUiNode(
                """{"@type":"button","label":"Worktree","event":{"type":"select_worktree","path":"/tmp/clicked"}}""",
            ) as UiNode.Button
        assertEquals("Worktree", worktreeButton.label)
        assertEquals(
            "/tmp/clicked",
            JSONObject(requireNotNull(worktreeButton.event).json).getString("path"),
        )

        assertEquals(
            UiNode.Input("Input", UiEvent("{\"type\":\"input\"}"), "draft"),
            parseUiNode(
                """{"@type":"input","label":"Input","event":{"type":"input"},"text":"draft"}""",
            ),
        )

        listOf(
            """{"@type":"text"}""",
            """{"@type":"text","text":1}""",
            """{"@type":"row"}""",
            """{"@type":"row","children":{}}""",
            """{"@type":"row","children":["bad"]}""",
            """{"@type":"button","label":"Event","event":"not-an-object"}""",
            """{"@type":"input","event":{"type":"input"}}""",
            """{"@type":"input","label":1,"event":{"type":"input"}}""",
            """{"@type":"input","label":"Input"}""",
            """{"@type":"input","label":"Input","event":"not-an-object"}""",
            """{"@type":"input","label":"Input","event":{"type":"input"},"text":1}""",
        ).forEach { json ->
            try {
                parseUiNode(json)
                fail("Unsupported document was accepted: $json")
            } catch (_: Exception) {
            }
        }
    }

    @Test
    fun buildsEventRequestEnvelope() {
        val request =
            JSONObject(eventRequest(UiEvent("{\"type\":\"run_claude\"}"), "draft"))

        assertEquals("run_claude", request.getJSONObject("event").getString("type"))
        assertEquals("draft", request.getString("value"))
        assertEquals(
            true,
            JSONObject(eventRequest(UiEvent("{\"type\":\"load\"}"), null)).isNull("value"),
        )
    }

    @Test
    fun replacesDisplayedDocumentForEachStreamedLine() {
        val documents =
            listOf(
                """{"@type":"text","text":"Hel"}""",
                """{"@type":"text","text":"Hello"}""",
            ).map(::parseUiNode)
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
                UiNode.Input("Input", UiEvent("{\"type\":\"input\"}")),
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
            assertEquals(UiEvent("{\"type\":\"input\"}") to "draft", submitted)
        }
    }

    @Test
    fun buttonSubmitsItsEvent() {
        var submitted: UiEvent? = null
        composeRule.setContent {
            UiNodeContent(
                UiNode.Button("Worktree", UiEvent("{\"type\":\"select_worktree\"}")),
                { event -> submitted = event },
                { _, _ -> },
                false,
            )
        }

        composeRule.onNodeWithText("Worktree").performClick()

        composeRule.runOnIdle {
            assertEquals(UiEvent("{\"type\":\"select_worktree\"}"), submitted)
        }
    }

    @Test
    fun inputBlocksDuplicateEnterWhileSubmitting() {
        var calls = 0
        var inProgress by mutableStateOf(false)
        composeRule.setContent {
            UiNodeContent(
                UiNode.Input("Input", UiEvent("{\"type\":\"input\"}")),
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
                UiNode.Input("Input", UiEvent("{\"type\":\"input\"}")),
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
                    """{"@type":"input","label":"Input","event":{"type":"input"},"text":"seed"}""",
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
        var node by mutableStateOf<UiNode>(UiNode.Input("Input", UiEvent("{\"type\":\"input\"}"), "seed"))
        composeRule.setContent {
            UiNodeContent(node, {}, { _, _ -> }, false)
        }

        composeRule.onNodeWithTag("input").performTextInput("-draft")
        composeRule.runOnIdle {
            node = UiNode.Input("Input", UiEvent("{\"type\":\"input\"}"), "returned")
        }

        composeRule.onNodeWithTag("input").assertTextContains("returned")
    }
}
