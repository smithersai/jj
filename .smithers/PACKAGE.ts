import { Smithers as S } from "@smthrs/targets"

/** Writes and drift-checks `.smithers/factory.json` from `.smithers/FACTORY.ts`. */
const factoryProjection = S.FactoryProjection({ root: ".smithers/flows" })

export const Package = S.Package({ targets: { factoryProjection } })
