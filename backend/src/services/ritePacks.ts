/**
 * Rites are sold in packages. One payment (a Stripe Checkout session on the
 * web, a Play order on Android) buys a package's number of rites; each rite
 * is one burn. Prices live in Stripe and Play Console; the counts live here,
 * and the app's catalogue (lib/src/models/revenue_schema.dart) matches them.
 */
export interface RitePack {
  /** Short ID, used by the web checkout and in Stripe metadata. */
  id: string;
  rites: number;
  /** The Google Play product (a consumable). */
  productId: string;
}

/** Counts are distinct: a credit's count names its package. */
export const RITE_PACKS: readonly RitePack[] = [
  { id: 'pack7', rites: 7, productId: 'net.ignosis.studio.rite.pack7' },
  { id: 'pack21', rites: 21, productId: 'net.ignosis.studio.rite.pack21' },
  { id: 'pack100', rites: 100, productId: 'net.ignosis.studio.rite.pack100' },
];

export const ritePackById = (id: string): RitePack | undefined => RITE_PACKS.find((p) => p.id === id);

export const ritePackByProduct = (productId: string): RitePack | undefined =>
  RITE_PACKS.find((p) => p.productId === productId);

/**
 * Parses STRIPE_RITE_PRICES, `pack7=price_…,pack21=price_…,pack100=price_…`,
 * into a map from package ID to Stripe price. Unknown packages are dropped.
 */
export function parsePackPrices(value: string): Map<string, string> {
  const prices = new Map<string, string>();
  for (const entry of value.split(',')) {
    const [id, price] = entry.split('=').map((s) => s?.trim() ?? '');
    if (id && price && ritePackById(id)) prices.set(id, price);
  }
  return prices;
}
