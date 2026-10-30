// The only JavaScript of the site. It reads two small files and shows them:
//   version.json     {"version": "1.0.0"}
//   changelog.json   the list of releases
// The paths are relative (no "/" at the start), so the site works in https://<you>.github.io/<repo>/

const versionBox = document.getElementById("version");
const changelogList = document.getElementById("changelog");
const themeButton = document.getElementById("theme");

async function loadJson(path) {
    // "?t=" gives a new address every time, so the browser never shows an OLD copy of the file
    const response = await fetch(path + "?t=" + Date.now());
    if (!response.ok) {
        throw new Error(path + " answered " + response.status);
    }
    return response.json();
}

async function showVersion() {
    try {
        const data = await loadJson("version.json");
        versionBox.textContent = "v" + data.version;
    } catch (error) {
        versionBox.textContent = "unknown";
        console.error(error);
    }
}

async function showChangelog() {
    try {
        const data = await loadJson("changelog.json");
        data.entries.slice().reverse().forEach(entry => {
            const item = document.createElement("li");
            item.innerHTML = "<strong></strong> <span class=\"hint\"></span><br><span class=\"notes\"></span>";
            item.querySelector("strong").textContent = "v" + entry.version;
            item.querySelector(".hint").textContent = "(" + entry.date + ")";
            item.querySelector(".notes").textContent = entry.notes;
            changelogList.appendChild(item);
        });
    } catch (error) {
        changelogList.innerHTML = "<li>Could not load the changelog.</li>";
        console.error(error);
    }
}

function applyTheme(dark) {
    document.body.classList.toggle("dark", dark);
    themeButton.textContent = dark ? "Switch to light mode" : "Switch to dark mode";
}

themeButton.addEventListener("click", () => {
    const dark = !document.body.classList.contains("dark");
    applyTheme(dark);
    try {
        localStorage.setItem("dark", dark ? "yes" : "no");
    } catch (error) {
        // a browser can forbid localStorage: the theme just will not be remembered
    }
});

try {
    applyTheme(localStorage.getItem("dark") === "yes");
} catch (error) {
    applyTheme(false);
}

showVersion();
showChangelog();
