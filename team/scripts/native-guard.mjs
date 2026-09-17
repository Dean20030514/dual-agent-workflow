// Cordis adapter over the native Agent registry, pinned by the capability spike.
// It does not perform inference or replace the DSH agent/runtime.
import { writeFileSync, renameSync } from 'node:fs';
import { resolve } from 'node:path';

export const name = 'team-native-guard';
export const inject = ['agents'];

export function installGuard(registry, config) {
  const create = registry.create.bind(registry);
  const resume = registry.resume.bind(registry);
  const records = [];
  const canonical = value => resolve(value).toLowerCase();
  const persist = () => {
    const temp = `${config.receipt}.tmp`;
    writeFileSync(temp, JSON.stringify({ schema_version: 1, agents: records }), 'utf8');
    renameSync(temp, config.receipt);
  };
  registry.create = async options => {
    // Reserve before the first await, including simultaneous spawn requests.
    if (records.length >= config.maxAgents) throw new Error('TEAM_AGENT_BUDGET');
    const depth = options.agentOptions?.subagentDepth ?? 0;
    if (depth > config.maxDepth || depth < 0 || !Number.isInteger(depth)) throw new Error('TEAM_AGENT_DEPTH');
    if (records.length > 0 && (!options.parentAgent || depth === 0)) throw new Error('TEAM_UNRELATED_AGENT');
    if (canonical(options.meta?.cwd ?? '') !== canonical(config.cwd)) throw new Error('TEAM_AGENT_CWD');
    if (options.agentOptions?.provider !== config.provider || options.agentOptions?.model !== config.model) {
      throw new Error('TEAM_MODEL_ROUTE');
    }
    const record = { id: options.sessionId, depth, provider: options.agentOptions.provider,
      model: options.agentOptions.model, cwd: config.cwd, state: 'creating' };
    records.push(record); persist();
    try {
      const handle = await create(options);
      record.state = 'created'; persist();
      return handle;
    } catch (error) { record.state = 'failed'; persist(); throw error; }
  };
  // Cold resume could reintroduce an unbudgeted session with an unrelated policy.
  registry.resume = async () => { throw new Error('TEAM_COLD_RESUME_FORBIDDEN'); };
  persist();
  return () => { registry.create = create; registry.resume = resume; };
}

export function apply(ctx, config) {
  const dispose = installGuard(ctx.agents, config);
  ctx.on('dispose', dispose);
}
