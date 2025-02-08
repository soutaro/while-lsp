/* --------------------------------------------------------------------------------------------
 * Copyright (c) Microsoft Corporation. All rights reserved.
 * Licensed under the MIT License. See License.txt in the project root for license information.
 * ------------------------------------------------------------------------------------------ */

import { workspace, ExtensionContext, commands, window } from 'vscode';

import {
	LanguageClient,
	LanguageClientOptions,
	ServerOptions,
	State
} from 'vscode-languageclient/node';

let client: LanguageClient | undefined

async function start() {
	const configuration = workspace.getConfiguration("while-lsp")
	const path = configuration.get<string>("serverFullPath")

	if (path) {
		const serverOptions: ServerOptions = {
			command: "ruby",
			args: [path],
			options: {
				shell: true
			}
		}

		const clientOptions: LanguageClientOptions = {
			documentSelector: [{ scheme: 'file', language: 'while' }]
		}

		client = new LanguageClient(
			'WhileLSP',
			'WhileLSP',
			serverOptions,
			clientOptions
		)

		client.start()
	} else {
		client = undefined
	}
}

export async function activate(context: ExtensionContext) {
	console.log("activated");
	let disposable = commands.registerCommand('while-lsp.start', async () => {
		if (client) {
			if (client.isRunning()) {
				await client.stop()
			}
		}
		await start()
	});
	context.subscriptions.push(disposable);
}

export async function deactivate() {
	if (client) {
		if (client.isRunning()) {
			await client.stop()
		}
	}
}
