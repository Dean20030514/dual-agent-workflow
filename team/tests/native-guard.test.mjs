import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { installGuard } from '../scripts/native-guard.mjs';

function fixture(maxAgents = 3, maxDepth = 2) {
  const cwd = mkdtempSync(join(tmpdir(), 'team-native-test-'));
  let creates = 0;
  const registry = { create: async options => { creates++; return { agent: options }; }, resume: async () => ({}) };
  const config = { maxAgents, maxDepth, cwd, provider: 'deepseek-official', model: 'deepseek-flash', receipt: join(cwd, 'agents.json') };
  installGuard(registry, config);
  const options = (id, depth = 0) => ({ sessionId: id, meta: {cwd}, parentAgent: depth ? {} : undefined,
    agentOptions: {provider: config.provider, model: config.model, subagentDepth: depth} });
  return { registry, config, options, count: () => creates };
}

test('native factory remains the executor and records the actual route', async () => {
  const f = fixture(); await f.registry.create(f.options('root'));
  assert.equal(f.count(), 1);
  const receipt = JSON.parse(readFileSync(f.config.receipt));
  assert.equal(receipt.agents[0].model, 'deepseek-flash');
  assert.equal(receipt.agents[0].state, 'created');
});
test('reserves before await so parallel starts cannot exceed cap', async () => {
  const f = fixture(2); await f.registry.create(f.options('root'));
  const outcomes = await Promise.allSettled([f.registry.create(f.options('a', 1)), f.registry.create(f.options('b', 1))]);
  assert.equal(outcomes.filter(x => x.status === 'fulfilled').length, 1);
  assert.equal(f.count(), 2);
});
test('rejects third depth, foreign cwd, route expansion and cold resume', async () => {
  const f = fixture(10); await f.registry.create(f.options('root'));
  await assert.rejects(f.registry.create(f.options('deep', 3)), /TEAM_AGENT_DEPTH/);
  const foreign = f.options('foreign', 1); foreign.meta.cwd = tmpdir();
  await assert.rejects(f.registry.create(foreign), /TEAM_AGENT_CWD/);
  const wrong = f.options('wrong', 1); wrong.agentOptions.model = 'other';
  await assert.rejects(f.registry.create(wrong), /TEAM_MODEL_ROUTE/);
  await assert.rejects(f.registry.resume({}), /TEAM_COLD_RESUME_FORBIDDEN/);
  assert.equal(f.count(), 1);
});
test('L1 creation cap forbids delegation before native creation', async () => {
  const f = fixture(1, 0); await f.registry.create(f.options('root'));
  await assert.rejects(f.registry.create(f.options('child', 1)), /TEAM_AGENT_BUDGET/);
  assert.equal(f.count(), 1);
});

test('live cost control blocks further children without stopping an existing family', async () => {
  const f = fixture(4);
  f.config.budgetControl = join(f.config.cwd, 'budget-control.json');
  writeFileSync(f.config.budgetControl, JSON.stringify({stop_new_children: false}));
  await f.registry.create(f.options('root'));
  await f.registry.create(f.options('before-limit', 1));
  writeFileSync(f.config.budgetControl, JSON.stringify({stop_new_children: true}));
  await assert.rejects(f.registry.create(f.options('after-limit', 1)), /TEAM_COST_SOFT_LIMIT/);
  assert.equal(f.count(), 2);
  assert.equal(JSON.parse(readFileSync(f.config.receipt)).agents.length, 2);
});
