// Commands that run `thor add` in the integrated terminal, from the folder
// of the open file (thor finds the project there or above it).
const path = require('path');
const vscode = require('vscode');

/** `thor add <kind>`: what each command asks for and how it checks it. */
const kinds = {
  'thor.addPage': {
    kind: 'page',
    prompt: 'URL of the page',
    placeHolder: '/about, /products/:id',
    valid: (v) => (v.startsWith('/') ? null : 'The URL starts with /'),
  },
  'thor.addComponent': {
    kind: 'component',
    prompt: 'Name of the component (UpperCamelCase)',
    placeHolder: 'ProductCard',
    valid: (v) => (/^[A-Z][A-Za-z0-9]*$/.test(v) ? null : 'UpperCamelCase: ProductCard'),
  },
  'thor.addState': {
    kind: 'state',
    prompt: 'Name of the state (UpperCamelCase)',
    placeHolder: 'Cart',
    valid: (v) => (/^[A-Z][A-Za-z0-9]*$/.test(v) ? null : 'UpperCamelCase: Cart'),
  },
};

/** The folder `thor add` runs from: the open file's, else the workspace's. */
function projectFolder() {
  const doc = vscode.window.activeTextEditor?.document;
  if (doc && doc.uri.scheme === 'file') return path.dirname(doc.uri.fsPath);
  return vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
}

function quote(arg) {
  return /^[\w/:.-]+$/.test(arg) ? arg : `'${arg.replace(/'/g, `'\\''`)}'`;
}

function activate(context) {
  for (const [command, spec] of Object.entries(kinds)) {
    context.subscriptions.push(
      vscode.commands.registerCommand(command, async () => {
        const value = await vscode.window.showInputBox({
          prompt: spec.prompt,
          placeHolder: spec.placeHolder,
          validateInput: (v) => spec.valid(v.trim()),
        });
        if (!value) return;
        const cwd = projectFolder();
        const terminal = vscode.window.createTerminal({ name: 'thor add', cwd });
        terminal.show();
        terminal.sendText(`thor add ${spec.kind} ${quote(value.trim())}`);
      }),
    );
  }
}

function deactivate() {}

module.exports = { activate, deactivate };
