const tabs = [...document.querySelectorAll("[data-tab]")];
function selectTab(tab, focus = false) {
  tabs.forEach((item) => {
    const selected = item === tab;
    item.setAttribute("aria-selected", String(selected));
    item.tabIndex = selected ? 0 : -1;
    document.getElementById(`panel-${item.dataset.tab}`).hidden = !selected;
  });
  if (focus) tab.focus();
}
tabs.forEach((tab, index) => {
  tab.addEventListener("click", () => selectTab(tab));
  tab.addEventListener("keydown", (event) => {
    let next;
    if (event.key === "ArrowRight") next = (index + 1) % tabs.length;
    if (event.key === "ArrowLeft")
      next = (index - 1 + tabs.length) % tabs.length;
    if (event.key === "Home") next = 0;
    if (event.key === "End") next = tabs.length - 1;
    if (next !== undefined) {
      event.preventDefault();
      selectTab(tabs[next], true);
    }
  });
});
const feedback = document.querySelector("#answer-feedback p");
document.querySelectorAll("[data-answer]").forEach((button) => {
  button.addEventListener("click", () => {
    document.querySelectorAll("[data-answer]").forEach((other) => {
      other.classList.remove("correct", "wrong");
      other.setAttribute("aria-pressed", String(other === button));
    });
    const correct = button.dataset.answer === "correct";
    button.classList.add(correct ? "correct" : "wrong");
    feedback.textContent = correct
      ? "Exactly. Both names refer to one list, so the change is visible through items too. Try “Connect the ideas” to see why."
      : "A reasonable guess. Assignment did not copy the list: alias and items refer to the same object. Try again, or open “Connect the ideas.”";
  });
});
const tree = document.getElementById("pixel-tree");
function drawTree(days) {
  const palette = [
    "#e3e9d9",
    "#725d3e",
    "#a18654",
    "#315d38",
    "#4d783e",
    "#779a50",
    "#a5bd67",
  ];
  const pixels = new Map();
  const put = (x, y, color) => pixels.set(`${x},${y}`, color);
  for (let x = 10; x <= 22; x++) put(x, 31, 0);
  if (days === 2) {
    for (let y = 24; y <= 30; y++) put(16, y, 3);
    [
      [13, 25],
      [14, 25],
      [15, 26],
      [17, 24],
      [18, 24],
      [17, 25],
    ].forEach(([x, y], i) => put(x, y, i % 2 ? 4 : 6));
  } else {
    const radius = days === 7 ? 6 : 12,
      cy = days === 7 ? 20 : 15;
    for (let y = cy; y <= 30; y++) {
      put(15, y, 2);
      put(16, y, 1);
    }
    for (let y = 1; y < 29; y++)
      for (let x = 1; x < 31; x++) {
        const px = x - 16,
          py = y - cy;
        const lobes = [
          [-0.4, -0.15, 0.66, 0.57],
          [0.18, -0.5, 0.63, 0.54],
          [0.53, 0.03, 0.57, 0.55],
          [-0.35, 0.37, 0.63, 0.47],
          [0.22, 0.4, 0.66, 0.45],
        ];
        if (
          lobes.some(
            ([a, b, rx, ry]) =>
              ((px - a * radius) / (rx * radius)) ** 2 +
                ((py - b * radius) / (ry * radius)) ** 2 <=
              1,
          )
        )
          put(
            x,
            y,
            py < -radius * 0.3
              ? 6
              : py < radius * 0.2
                ? 5
                : (x + y) % 7 === 0
                  ? 3
                  : 4,
          );
      }
  }
  tree.replaceChildren(
    ...[...pixels].map(([key, color]) => {
      const [x, y] = key.split(",");
      const rect = document.createElementNS(
        "http://www.w3.org/2000/svg",
        "rect",
      );
      rect.setAttribute("x", x);
      rect.setAttribute("y", y);
      rect.setAttribute("width", "1");
      rect.setAttribute("height", "1");
      rect.setAttribute("fill", palette[color]);
      return rect;
    }),
  );
  const label =
    days === 2
      ? "a small beginning"
      : days === 7
        ? "taking root"
        : "room to branch out";
  tree.setAttribute(
    "aria-label",
    `Pixel learning tree with ${days} practice days`,
  );
  document.getElementById("tree-caption").textContent =
    `${days} practice days · ${label}`;
}
document.querySelectorAll("[data-days]").forEach((button) =>
  button.addEventListener("click", () => {
    document
      .querySelectorAll("[data-days]")
      .forEach((other) =>
        other.setAttribute("aria-pressed", String(other === button)),
      );
    drawTree(Number(button.dataset.days));
  }),
);
drawTree(2);
function revealInstallHelp() {
  if (location.hash === "#install-help")
    document.getElementById("install-help").open = true;
}
window.addEventListener("hashchange", revealInstallHelp);
revealInstallHelp();
