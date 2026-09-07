# Plam learning design: evidence and product decisions

Research date: 2026-09-05. This supplements PRODUCT_BLUEPRINT.md. It distinguishes published findings from proposed application behavior. The complete Plam workflow has not been experimentally validated.

## What the evidence supports

### 1. Retrieve information, then explain and apply it

Karpicke and Blunt (2011) found that retrieval practice improved learning from science texts relative to elaborative concept mapping, including questions requiring inference. This supports practicing reconstruction of knowledge; it does not establish that any multiple-choice quiz produces deep code understanding. [Primary study](https://pubmed.ncbi.nlm.nih.gov/21252317/).

Decision: after an explanation, ask the learner to retrieve the central idea and use it. Include output prediction, purpose explanation, and change-impact questions. Hide the teaching explanation during retrieval, while retaining the source code when inspecting code is the skill being assessed.

### 2. Repeat practice across time

Cepeda and colleagues (2008) studied fact learning with long review and test delays. The best gap depended on how long the information needed to be retained. A single universal schedule is not established by this work. [Author-hosted paper](https://www.evullab.org/pdf/CepedaVulRohrerWixtedPashler-PS-2008.pdf).

Decision: schedule future retrieval and adapt intervals from review performance. FSRS is an implementation choice; this study does not validate FSRS for repository comprehension. Maintain stable retrieval objectives across equivalent generated variants, and separately evaluate delayed explanation and transfer.

### 3. Give novices examples, then remove support

Renkl and colleagues (2002) tested gradual removal of worked solution steps in a field experiment and two laboratory experiments. The reported benefits included near transfer. Generalization to distant problems should not be assumed. [Authors' institutional publication record](https://asu.elsevierpure.com/en/publications/from-example-study-to-problem-solving-smooth-transitions-help-lea/).

Decision: show a worked trace, then a partly completed trace, then a fresh problem. Learners demonstrating prior knowledge can start with the independent task. Neither a long compulsory tutorial nor unsupported trial-and-error is the universal starting point.

### 4. Use code self-explanation selectively

Oli and colleagues' 2023 DeepCodeTutor trial recruited 90 introductory Java students. It did not find a significant overall advantage of scaffolded self-explanation over reading annotated examples. The reported prior-knowledge subgroup pattern is suggestive and does not prove a treatment benefit for every novice. Ceiling effects and analysis exclusions limit interpretation. [Primary paper](https://par.nsf.gov/servlets/purl/10482232).

Decision: ask targeted questions about purpose and mechanism, give hints when useful, and allow direct explanations. Do not require a paragraph explaining every line or equate longer conversations with greater understanding.

### 5. Correct misleading answers

Butler and Roediger (2008) found that feedback improved the benefits of multiple-choice testing and reduced later recall of incorrect alternatives. Both immediate and delayed feedback helped compared with no feedback. [Primary study](https://pubmed.ncbi.nlm.nih.gov/18491500/).

Decision: after an attempt, explain the governing idea and the error in the selected alternative. A learner who guessed correctly should still see useful feedback. Use feedback after each practice attempt for usability; withhold it until the end of independent checkpoints to avoid contaminating later answers. Immediate feedback is not claimed to be universally optimal.

### 6. Mix related problem types

Rohrer, Dedrick, and Stershic (2015) compared interleaved and blocked mathematics practice and reported better later test performance with interleaving. This is evidence from mathematics, not a direct test of repository learning. [Primary paper](https://files.eric.ed.gov/fulltext/ED557355.pdf).

Decision: once the relevant foundations are available, mix confusable concepts and require choosing an approach. Examples include authentication versus authorization, mutation versus reassignment, and sequential versus concurrent work. Randomly changing unrelated subjects is not the intended mechanism.

### 7. Test transfer separately from remembering

Corral and Carpenter (2025) studied research-methods concepts in three experiments. One short practice round did not show an application benefit; repeated retrieval with a one-week test produced stronger retention and application evidence, with results varying across comparisons. The application tests used new multiple-choice scenarios. [Primary paper](https://doi.org/10.1016/j.learninstruc.2025.102219).

Decision: use unseen examples and delayed checkpoints. Do not claim that success on these items establishes the ability to independently debug an unfamiliar production repository. Include authentic repository tasks as a separate outcome.

### 8. Measure performance without AI assistance

Bastani and colleagues' high-school mathematics experiment found that unrestricted GPT assistance improved practice performance but harmed subsequent unaided exam performance; a constrained tutor largely mitigated that harm without establishing a positive unaided learning effect. This is short-term mathematics evidence, not a direct evaluation of Plam or experienced developers. [Author-hosted paper](https://hamsabastani.github.io/education_llm.pdf).

Decision: tutoring offers progressively more specific hints and an explicit explanation/reveal action. The learner can always choose help. Record assistance and follow it with a fresh opportunity to answer independently; do not award independent-mastery evidence for reproducing a revealed answer.

## The lesson loop

The app uses a flexible sequence:

**Diagnose → explain with an example → guided attempt → independent attempt → feedback → changed example → later retrieval.**

This sequence is our synthesis of the evidence, not a protocol tested as a whole. All topic content is generated dynamically. The teaching structures, evidence rules, and assessment schemas are application logic.

Use the learner's time budget and progress to size the session. Fifteen questions, a ten-minute lesson, an 80% threshold, or a fixed easy/hard ratio must not be presented as research-established optima.

### Example: closures and independent state

Start with a short explanation and a worked trace showing how a returned function retains access to its lexical environment. Then present:

```javascript
function makeCounter() {
  let n = 0;
  return () => ++n;
}

const a = makeCounter();
const b = makeCounter();
console.log(a(), a(), b());
```

The expected values are 1, 2, 1. Ask for the prediction before displaying it. A guided hint can ask how many calls to makeCounter occurred and which invocation created each n. Feedback should address the specific confusion, such as assuming that both returned functions share one counter.

Next ask why the state survives after makeCounter returns. Then show a fresh example where two returned methods close over the same variable, and ask how that differs. In a repository course, connect the concept to an actual selected callback or stateful function with source evidence. On a later day, use a different example and an independent explanation question.

Keep the code visible for tracing and explanation. The goal is reasoning about code, not memorizing variable names or file paths.

## Question generation and grading contracts

Every generated item records:

- The concept, prerequisite, and observable learning objective.
- Its role: diagnosis, guided practice, independent practice, or delayed checkpoint.
- The question format and cognitive demand: recall, trace, explain, discriminate, diagnose, or transfer.
- Source references and the code snapshot when relevant.
- A validated answer or rubric, acceptable alternative explanations, and common misconceptions.
- A hint progression, feedback, and the identity of equivalent variants.
- Assistance availability and whether its result may affect mastery or scheduling.

Multiple choice is suitable when comparing plausible alternatives is useful. Distractors should represent real reasoning errors and receive corrective feedback. True/false items should usually require a reason or a correction. Cloze should test a meaningful idea or code step. Short explanations should be graded for claims and reasoning, not verbal similarity to the model answer. Output questions must specify language and relevant runtime assumptions.

The tutor asks for only the missing part of an otherwise sound explanation. It accepts concise answers, pseudocode, diagrams where supported, and equivalent wording. Ambiguity, missing context, nondeterministic output, or conflicting sources make an item unsuitable for confident automatic grading.

## Adaptation policy

| Observed evidence | Next teaching action |
| --- | --- |
| Missing prerequisite | Offer a focused explanation and worked example |
| Correct independent answer with sound reasoning | Reduce guidance and try a different context |
| Correct choice with uncertainty or weak reasoning | Clarify the mechanism and check another example |
| Incorrect answer with strong confidence | Contrast the misconception with a counterexample |
| Repeated errors despite hints | Change the representation or revisit a prerequisite |
| Correct immediately after revealing the answer | Record assisted completion and arrange a fresh independent check |
| Repeated later success on varied examples | Space reviews further apart |
| Curiosity about an adjacent topic | Save or explore the doubt without automatically lowering mastery |

Confidence can be collected occasionally with a lightweight control; it is supporting context, not a grade. Do not use typing speed as a proxy for understanding. These branching rules are product hypotheses to evaluate and adjust, not universal prescriptions from the cited studies.

## Notes and the tutor

At wrap-up, invite a short recall of the lesson before showing the recap. Offer an editable note that combines the central idea, one example, one pitfall, and unresolved questions. Skipping the recall step is allowed. Passive note generation alone is not evidence that learning occurred.

Store the exact response and grading evidence in SQLite. A misconception memory is a tentative interpretation with supporting event IDs, not a permanent label. Mem0 can retrieve useful past context; it cannot determine the mastery score.

The teaching policy belongs to a dedicated LearningEngine in the app, with explicit state transitions and structured outputs. Models generate content and propose evaluations; the engine controls what evidence counts and what activity follows. This prevents the entire educational design from becoming one loosely specified agent prompt.

## Completion and evaluation

Represent progress as evidence for recall, tracing, explanation, diagnosis, and transfer, together with recency and assistance. Prefer statements such as “explained independently; delayed review pending” over an uncalibrated “92% mastery.”

Evaluate the full product using:

- Delayed independent checks, including roughly one-week and longer follow-ups as evaluation windows, not compulsory review intervals.
- Unseen examples assessing the same underlying objective.
- Authentic repository tasks, such as finding an entry point, explaining a failure path, or identifying a change's likely impact with evidence.
- Rates of ambiguous questions, disputed grades, unsupported explanations, and unnecessary tutor interruptions.
- Study time, perceived effort, and willingness to return alongside learning outcomes.

A personal before/after record can show progress but does not establish causality. If comparing teaching policies, use comparable concepts, hold study opportunity reasonably constant, avoid repeating the evaluation item, and account for carryover. Small personal samples do not justify broad effectiveness claims.

These learning behaviors are part of the complete product scope. The studies support the ingredients with differing strength; the exact combination, generated-content quality, scheduling integration, and repository transfer still require validation.
