import type { Allergen, Cuisine } from '@/schemas/profile';
import type { FoodDefinition, FoodTag, Macros } from '@/schemas/nutrition';

/**
 * On-device food table.
 *
 * Deliberately curated rather than comprehensive. A 900,000-row nutrition
 * database is a search problem; what this product needs is a few hundred foods
 * people in its target markets actually eat, with macros good enough to make a
 * daily total meaningful. Weighted toward Indian home and restaurant food,
 * then Mediterranean and the generic Western staples, matching the cuisine
 * options in the profile.
 *
 * Figures are per the stated portion, drawn from IFCT 2017 (Indian Food
 * Composition Tables) and USDA FoodData Central, rounded to the precision that
 * survives someone eyeballing a serving size. Sodium is the weakest column —
 * restaurant salt varies enormously — so it is used for direction, not
 * arithmetic.
 */

interface FoodInput {
  cuisine?: Cuisine;
  tags?: FoodTag[];
  allergens?: Allergen[];
  vegetarian?: boolean;
  vegan?: boolean;
  jainSafe?: boolean;
  containsPork?: boolean;
  containsAlcohol?: boolean;
}

/** `[kcal, protein, carbs, fat, fibre, addedSugar, sodium]` for the portion. */
type MacroTuple = [number, number, number, number, number, number, number];

function food(
  id: string,
  name: string,
  portionLabel: string,
  macros: MacroTuple,
  input: FoodInput = {},
): FoodDefinition {
  const [calories, proteinG, carbsG, fatG, fibreG, addedSugarG, sodiumMg] = macros;
  const resolved: Macros = { calories, proteinG, carbsG, fatG, fibreG, addedSugarG, sodiumMg };

  return {
    id,
    name,
    portionLabel,
    cuisine: input.cuisine ?? null,
    macros: resolved,
    tags: input.tags ?? [],
    allergens: input.allergens ?? [],
    // Vegan implies vegetarian; declaring both at every call site invites drift.
    vegetarian: input.vegan === true ? true : (input.vegetarian ?? false),
    vegan: input.vegan ?? false,
    jainSafe: input.jainSafe ?? false,
    containsPork: input.containsPork ?? false,
    containsAlcohol: input.containsAlcohol ?? false,
  };
}

export const FOOD_DATABASE: readonly FoodDefinition[] = [
  // -------------------------------------------------------------------------
  // North Indian
  // -------------------------------------------------------------------------
  food('roti', 'Roti / chapati', '1 medium, ~40 g', [104, 3.1, 20, 1.4, 2.6, 0, 95], {
    cuisine: 'north-indian',
    tags: ['wholegrain', 'high-fibre'],
    allergens: ['gluten'],
    vegan: true,
    jainSafe: true,
  }),
  food('naan', 'Butter naan', '1 piece, ~90 g', [262, 7.4, 42, 7.2, 1.8, 2, 420], {
    cuisine: 'north-indian',
    allergens: ['gluten', 'dairy'],
    vegetarian: true,
    jainSafe: true,
  }),
  food('aloo-paratha', 'Aloo paratha', '1 piece with ghee', [318, 6.8, 44, 13, 3.4, 0, 380], {
    cuisine: 'north-indian',
    allergens: ['gluten', 'dairy'],
    vegetarian: true,
  }),
  food('plain-rice', 'Steamed white rice', '1 cup cooked, ~150 g', [205, 4.3, 45, 0.4, 0.6, 0, 2], {
    cuisine: 'north-indian',
    vegan: true,
    jainSafe: true,
  }),
  food('jeera-rice', 'Jeera rice', '1 cup, ~160 g', [265, 4.6, 46, 7, 1, 0, 320], {
    cuisine: 'north-indian',
    vegetarian: true,
  }),
  food('brown-rice', 'Brown rice', '1 cup cooked, ~150 g', [216, 5, 45, 1.8, 3.5, 0, 5], {
    tags: ['wholegrain', 'high-fibre'],
    vegan: true,
    jainSafe: true,
  }),
  food('dal-tadka', 'Dal tadka', '1 bowl, ~200 g', [198, 11.5, 26, 5.4, 7.8, 0, 460], {
    cuisine: 'north-indian',
    tags: ['high-protein', 'high-fibre', 'iron-rich'],
    vegetarian: true,
  }),
  food('dal-makhani', 'Dal makhani', '1 bowl, ~200 g', [327, 12, 28, 18, 8.2, 0, 620], {
    cuisine: 'north-indian',
    tags: ['high-protein', 'high-fibre'],
    allergens: ['dairy'],
    vegetarian: true,
  }),
  food('rajma', 'Rajma masala', '1 bowl, ~200 g', [245, 12.8, 34, 6.5, 11, 0, 540], {
    cuisine: 'north-indian',
    tags: ['high-protein', 'high-fibre', 'iron-rich'],
    vegetarian: true,
  }),
  food('chole', 'Chole (chickpea curry)', '1 bowl, ~200 g', [269, 12.2, 36, 8.4, 10.6, 0, 580], {
    cuisine: 'north-indian',
    tags: ['high-protein', 'high-fibre', 'iron-rich'],
    vegetarian: true,
  }),
  food('palak-paneer', 'Palak paneer', '1 bowl, ~200 g', [305, 14.5, 12, 23, 4.6, 0, 610], {
    cuisine: 'north-indian',
    tags: ['high-protein', 'iron-rich', 'leafy-green', 'calcium-rich'],
    allergens: ['dairy'],
    vegetarian: true,
  }),
  food('paneer-tikka', 'Paneer tikka (dry)', '6 pieces, ~150 g', [286, 18.5, 9, 20, 2, 0, 520], {
    cuisine: 'north-indian',
    tags: ['high-protein', 'low-carb', 'calcium-rich'],
    allergens: ['dairy'],
    vegetarian: true,
  }),
  food('bhindi-masala', 'Bhindi masala', '1 bowl, ~150 g', [148, 3.2, 12, 10, 5.4, 0, 410], {
    cuisine: 'north-indian',
    tags: ['high-fibre', 'low-carb'],
    vegan: true,
  }),
  food('mixed-sabzi', 'Mixed vegetable sabzi', '1 bowl, ~180 g', [135, 4.1, 16, 6.4, 6.2, 0, 390], {
    cuisine: 'north-indian',
    tags: ['high-fibre'],
    vegan: true,
  }),
  food('tandoori-chicken', 'Tandoori chicken', '2 pieces, ~200 g', [312, 41, 4, 14, 0.8, 0, 690], {
    cuisine: 'north-indian',
    tags: ['high-protein', 'low-carb'],
    allergens: ['dairy'],
  }),
  food('chicken-tikka', 'Chicken tikka (dry)', '6 pieces, ~150 g', [268, 34, 5, 12, 0.6, 0, 640], {
    cuisine: 'north-indian',
    tags: ['high-protein', 'low-carb'],
    allergens: ['dairy'],
  }),
  food('butter-chicken', 'Butter chicken', '1 bowl, ~220 g', [438, 27, 14, 31, 1.8, 4, 780], {
    cuisine: 'north-indian',
    tags: ['high-protein'],
    allergens: ['dairy', 'tree-nut'],
  }),
  food('chicken-biryani', 'Chicken biryani', '1 plate, ~350 g', [582, 28, 68, 21, 3.6, 0, 980], {
    cuisine: 'north-indian',
    tags: ['high-protein'],
    allergens: ['dairy'],
  }),
  food('raita', 'Cucumber raita', '1 small bowl, ~120 g', [72, 4.2, 6, 3.4, 0.8, 0, 210], {
    cuisine: 'north-indian',
    tags: ['probiotic', 'calcium-rich'],
    allergens: ['dairy'],
    vegetarian: true,
  }),
  food('samosa', 'Samosa', '1 piece, ~60 g', [198, 3.6, 24, 10, 2.2, 0, 340], {
    cuisine: 'north-indian',
    tags: ['fried', 'ultra-processed'],
    allergens: ['gluten'],
    vegetarian: true,
  }),
  food('pakora', 'Onion pakora', '5 pieces, ~80 g', [284, 6.4, 28, 16, 3.4, 0, 460], {
    cuisine: 'north-indian',
    tags: ['fried'],
    vegan: true,
  }),
  food('gulab-jamun', 'Gulab jamun', '2 pieces', [312, 4.2, 46, 12, 0.4, 34, 120], {
    cuisine: 'north-indian',
    tags: ['sugary', 'ultra-processed'],
    allergens: ['dairy', 'gluten'],
    vegetarian: true,
  }),
  food('sweet-lassi', 'Sweet lassi', '1 glass, 250 mL', [216, 6.8, 34, 5.6, 0, 22, 95], {
    cuisine: 'north-indian',
    tags: ['sugary', 'probiotic', 'calcium-rich'],
    allergens: ['dairy'],
    vegetarian: true,
    jainSafe: true,
  }),
  food('masala-chai', 'Masala chai with sugar', '1 cup, 150 mL', [98, 2.4, 14, 3.4, 0, 10, 45], {
    cuisine: 'north-indian',
    tags: ['sugary'],
    allergens: ['dairy'],
    vegetarian: true,
    jainSafe: true,
  }),

  // -------------------------------------------------------------------------
  // South Indian
  // -------------------------------------------------------------------------
  food('idli', 'Idli', '2 pieces', [116, 4.2, 24, 0.6, 1.4, 0, 220], {
    cuisine: 'south-indian',
    tags: ['probiotic'],
    vegan: true,
    jainSafe: true,
  }),
  food('plain-dosa', 'Plain dosa', '1 large', [168, 4.4, 28, 4.6, 1.6, 0, 240], {
    cuisine: 'south-indian',
    vegan: true,
    jainSafe: true,
  }),
  food('masala-dosa', 'Masala dosa', '1 large with filling', [312, 6.8, 46, 11, 3.8, 0, 480], {
    cuisine: 'south-indian',
    vegetarian: true,
  }),
  food('uttapam', 'Onion uttapam', '1 piece', [204, 6.2, 32, 5.6, 2.8, 0, 320], {
    cuisine: 'south-indian',
    vegan: true,
  }),
  food('sambar', 'Sambar', '1 bowl, ~180 g', [142, 7.8, 20, 3.6, 6.4, 0, 520], {
    cuisine: 'south-indian',
    tags: ['high-fibre', 'iron-rich'],
    vegan: true,
  }),
  food('rasam', 'Rasam', '1 bowl, ~180 g', [68, 3.2, 10, 1.8, 2.4, 0, 480], {
    cuisine: 'south-indian',
    tags: ['low-carb'],
    vegan: true,
  }),
  food('coconut-chutney', 'Coconut chutney', '2 tbsp', [86, 1.4, 4, 7.4, 2.2, 0, 140], {
    cuisine: 'south-indian',
    vegan: true,
  }),
  food('upma', 'Upma', '1 bowl, ~180 g', [232, 5.4, 34, 8.2, 2.6, 0, 420], {
    cuisine: 'south-indian',
    vegetarian: true,
  }),
  food('ven-pongal', 'Ven pongal', '1 bowl, ~200 g', [286, 8.2, 42, 9.4, 3.2, 0, 460], {
    cuisine: 'south-indian',
    allergens: ['dairy'],
    vegetarian: true,
  }),
  food('curd-rice', 'Curd rice', '1 bowl, ~220 g', [242, 7.6, 38, 6.2, 1, 0, 380], {
    cuisine: 'south-indian',
    tags: ['probiotic', 'calcium-rich'],
    allergens: ['dairy'],
    vegetarian: true,
    jainSafe: true,
  }),
  food('fish-curry', 'Kerala fish curry', '1 bowl, ~200 g', [232, 24, 8, 12, 1.6, 0, 620], {
    cuisine: 'south-indian',
    tags: ['high-protein', 'omega3-rich', 'low-carb'],
    allergens: ['fish'],
  }),
  food('medu-vada', 'Medu vada', '2 pieces', [268, 7.2, 26, 15, 4.2, 0, 380], {
    cuisine: 'south-indian',
    tags: ['fried'],
    vegan: true,
  }),
  food('filter-coffee', 'Filter coffee with sugar', '1 cup, 120 mL', [86, 2.8, 11, 3.2, 0, 8, 40], {
    cuisine: 'south-indian',
    tags: ['sugary'],
    allergens: ['dairy'],
    vegetarian: true,
    jainSafe: true,
  }),

  // -------------------------------------------------------------------------
  // Mediterranean & Middle Eastern
  // -------------------------------------------------------------------------
  food('grilled-chicken-salad', 'Grilled chicken salad', '1 large bowl, ~320 g', [364, 38, 14, 18, 5.2, 0, 520], {
    cuisine: 'mediterranean',
    tags: ['high-protein', 'low-carb', 'high-fibre', 'leafy-green'],
  }),
  food('greek-salad', 'Greek salad', '1 bowl, ~250 g', [248, 8.4, 12, 19, 4.4, 0, 640], {
    cuisine: 'mediterranean',
    tags: ['high-fibre', 'low-carb', 'calcium-rich'],
    allergens: ['dairy'],
    vegetarian: true,
  }),
  food('grilled-salmon', 'Grilled salmon fillet', '1 fillet, ~170 g', [354, 39, 0, 21, 0, 0, 180], {
    cuisine: 'mediterranean',
    tags: ['high-protein', 'omega3-rich', 'low-carb'],
    allergens: ['fish'],
  }),
  food('hummus-pita', 'Hummus with wholewheat pita', '3 tbsp + 1 pita', [312, 10.4, 42, 12, 7.4, 0, 480], {
    cuisine: 'middle-eastern',
    tags: ['high-fibre', 'wholegrain'],
    allergens: ['sesame', 'gluten'],
    vegan: true,
  }),
  food('falafel-wrap', 'Falafel wrap', '1 wrap, ~280 g', [486, 15, 58, 21, 9.2, 2, 780], {
    cuisine: 'middle-eastern',
    tags: ['high-fibre', 'fried'],
    allergens: ['gluten', 'sesame'],
    vegan: true,
  }),
  food('tabbouleh', 'Quinoa tabbouleh', '1 bowl, ~200 g', [232, 7.2, 32, 8.6, 6.8, 0, 320], {
    cuisine: 'middle-eastern',
    tags: ['high-fibre', 'wholegrain'],
    vegan: true,
  }),
  food('lentil-soup', 'Lentil soup', '1 bowl, ~300 mL', [186, 11.4, 28, 3.2, 8.6, 0, 620], {
    cuisine: 'middle-eastern',
    tags: ['high-protein', 'high-fibre', 'iron-rich'],
    vegan: true,
  }),
  food('shakshuka', 'Shakshuka', '1 pan, ~300 g', [284, 16.2, 16, 18, 4.8, 0, 680], {
    cuisine: 'middle-eastern',
    tags: ['high-protein', 'low-carb'],
    allergens: ['egg'],
    vegetarian: true,
  }),
  food('chicken-shawarma-plate', 'Chicken shawarma plate', '1 plate, ~350 g', [524, 42, 38, 24, 5.4, 0, 940], {
    cuisine: 'middle-eastern',
    tags: ['high-protein'],
    allergens: ['sesame', 'dairy'],
  }),

  // -------------------------------------------------------------------------
  // East Asian
  // -------------------------------------------------------------------------
  food('salmon-sushi', 'Salmon nigiri', '6 pieces', [312, 22, 42, 6.4, 1.2, 4, 620], {
    cuisine: 'japanese',
    tags: ['high-protein', 'omega3-rich'],
    allergens: ['fish', 'soy'],
  }),
  food('miso-soup', 'Miso soup', '1 bowl, ~200 mL', [58, 4.2, 6, 2.2, 1.4, 0, 720], {
    cuisine: 'japanese',
    tags: ['probiotic', 'low-carb'],
    allergens: ['soy'],
    vegan: true,
  }),
  food('chicken-teriyaki', 'Chicken teriyaki with rice', '1 plate, ~380 g', [612, 38, 76, 16, 2.4, 14, 1180], {
    cuisine: 'japanese',
    tags: ['high-protein'],
    allergens: ['soy', 'gluten'],
  }),
  food('pho', 'Beef pho', '1 bowl, ~500 mL', [418, 28, 52, 9.4, 3.2, 2, 1240], {
    cuisine: 'east-asian',
    tags: ['high-protein', 'iron-rich'],
    allergens: ['fish', 'soy'],
  }),
  food('pad-thai', 'Pad Thai with chicken', '1 plate, ~350 g', [648, 26, 82, 24, 4.2, 16, 1320], {
    cuisine: 'thai',
    allergens: ['peanut', 'egg', 'fish', 'soy'],
  }),
  food('tofu-stirfry', 'Tofu and vegetable stir-fry', '1 plate, ~300 g', [318, 21, 22, 17, 6.4, 4, 760], {
    cuisine: 'east-asian',
    tags: ['high-protein', 'high-fibre', 'calcium-rich'],
    allergens: ['soy', 'sesame'],
    vegan: true,
  }),
  food('edamame', 'Edamame', '1 cup, ~155 g', [188, 18.4, 14, 8.1, 8, 0, 380], {
    cuisine: 'japanese',
    tags: ['high-protein', 'high-fibre'],
    allergens: ['soy'],
    vegan: true,
  }),

  // -------------------------------------------------------------------------
  // Everyday staples
  // -------------------------------------------------------------------------
  food('oats-porridge', 'Oats porridge with milk', '1 bowl, ~250 g', [242, 10.2, 38, 5.8, 5.4, 0, 120], {
    tags: ['wholegrain', 'high-fibre'],
    allergens: ['gluten', 'dairy'],
    vegetarian: true,
    jainSafe: true,
  }),
  food('greek-yoghurt', 'Greek yoghurt, plain', '1 cup, ~200 g', [146, 20, 8, 4, 0, 0, 72], {
    tags: ['high-protein', 'probiotic', 'calcium-rich', 'low-carb'],
    allergens: ['dairy'],
    vegetarian: true,
    jainSafe: true,
  }),
  food('boiled-eggs', 'Boiled eggs', '2 large', [156, 12.6, 1.1, 11, 0, 0, 124], {
    tags: ['high-protein', 'low-carb'],
    allergens: ['egg'],
    vegetarian: true,
    jainSafe: true,
  }),
  food('veg-omelette', 'Vegetable omelette', '2 eggs', [226, 14.2, 4.2, 17, 1.2, 0, 380], {
    tags: ['high-protein', 'low-carb'],
    allergens: ['egg'],
    vegetarian: true,
  }),
  food('chicken-breast', 'Grilled chicken breast', '150 g', [248, 46, 0, 5.4, 0, 0, 132], {
    tags: ['high-protein', 'low-carb'],
  }),
  food('paneer', 'Paneer, pan-seared', '100 g', [296, 18.3, 3.6, 23, 0, 0, 22], {
    tags: ['high-protein', 'low-carb', 'calcium-rich'],
    allergens: ['dairy'],
    vegetarian: true,
    jainSafe: true,
  }),
  food('tofu', 'Firm tofu', '150 g', [216, 23, 5.4, 13, 2.4, 0, 24], {
    tags: ['high-protein', 'low-carb', 'calcium-rich'],
    allergens: ['soy'],
    vegan: true,
    jainSafe: true,
  }),
  food('whey-shake', 'Whey protein shake', '1 scoop in water', [124, 25, 3, 1.5, 0, 1, 90], {
    tags: ['high-protein', 'low-carb'],
    allergens: ['dairy'],
    vegetarian: true,
    jainSafe: true,
  }),
  food('cooked-spinach', 'Cooked spinach', '1 cup, ~180 g', [82, 5.3, 6.8, 3.2, 4.3, 0, 180], {
    tags: ['iron-rich', 'leafy-green', 'high-fibre', 'low-carb'],
    vegan: true,
    jainSafe: true,
  }),
  food('chickpea-salad', 'Chickpea salad', '1 bowl, ~250 g', [312, 13.4, 38, 12, 11.2, 0, 420], {
    tags: ['high-protein', 'high-fibre', 'iron-rich'],
    vegan: true,
  }),
  food('quinoa', 'Cooked quinoa', '1 cup, ~185 g', [222, 8.1, 39, 3.6, 5.2, 0, 13], {
    tags: ['wholegrain', 'high-fibre', 'high-protein'],
    vegan: true,
    jainSafe: true,
  }),
  food('sweet-potato', 'Baked sweet potato', '1 medium, ~150 g', [162, 3.6, 37, 0.2, 5.4, 0, 72], {
    tags: ['high-fibre'],
    vegan: true,
  }),
  food('avocado-toast', 'Avocado on wholegrain toast', '2 slices', [346, 9.2, 34, 20, 9.4, 0, 420], {
    tags: ['high-fibre', 'wholegrain'],
    allergens: ['gluten'],
    vegan: true,
    jainSafe: true,
  }),
  food('banana', 'Banana', '1 medium, ~120 g', [105, 1.3, 27, 0.4, 3.1, 0, 1], {
    tags: ['high-fibre'],
    vegan: true,
    jainSafe: true,
  }),
  food('orange', 'Orange', '1 medium', [62, 1.2, 15, 0.2, 3.1, 0, 0], {
    tags: ['vitamin-c-rich', 'high-fibre'],
    vegan: true,
    jainSafe: true,
  }),
  food('guava', 'Guava', '1 medium, ~120 g', [68, 2.6, 14, 0.9, 5.4, 0, 2], {
    tags: ['vitamin-c-rich', 'high-fibre'],
    vegan: true,
    jainSafe: true,
  }),
  food('almonds', 'Almonds', '20 pieces, ~24 g', [138, 5.1, 5.2, 12, 3, 0, 0], {
    tags: ['high-fibre'],
    allergens: ['tree-nut'],
    vegan: true,
    jainSafe: true,
  }),
  food('walnuts', 'Walnuts', '6 halves, ~20 g', [131, 3, 2.8, 13, 1.4, 0, 0], {
    tags: ['omega3-rich'],
    allergens: ['tree-nut'],
    vegan: true,
    jainSafe: true,
  }),
  food('black-coffee', 'Black coffee', '1 cup', [4, 0.3, 0, 0, 0, 0, 5], {
    tags: ['low-carb'],
    vegan: true,
    jainSafe: true,
  }),

  // -------------------------------------------------------------------------
  // The ones that make weekly patterns interesting
  // -------------------------------------------------------------------------
  food('cola', 'Cola', '330 mL can', [139, 0, 35, 0, 0, 35, 15], {
    tags: ['sugary', 'ultra-processed'],
    vegan: true,
    jainSafe: true,
  }),
  food('orange-juice', 'Orange juice, packaged', '250 mL', [112, 1.7, 26, 0.5, 0.5, 22, 8], {
    tags: ['sugary'],
    vegan: true,
    jainSafe: true,
  }),
  food('chocolate-bar', 'Milk chocolate bar', '45 g', [238, 3.4, 26, 13, 1.4, 24, 42], {
    tags: ['sugary', 'ultra-processed'],
    allergens: ['dairy', 'soy'],
    vegetarian: true,
    jainSafe: true,
  }),
  food('ice-cream', 'Vanilla ice cream', '2 scoops, ~130 g', [274, 4.6, 32, 14, 0.8, 28, 106], {
    tags: ['sugary', 'ultra-processed'],
    allergens: ['dairy'],
    vegetarian: true,
    jainSafe: true,
  }),
  food('fries', 'French fries', 'medium serving, ~120 g', [378, 4.2, 48, 18, 4.4, 0, 340], {
    tags: ['fried', 'ultra-processed'],
    vegan: true,
  }),
  food('cheeseburger', 'Cheeseburger', '1 regular', [536, 27, 42, 29, 2.2, 8, 1120], {
    cuisine: 'american',
    tags: ['ultra-processed'],
    allergens: ['gluten', 'dairy', 'sesame'],
  }),
  food('pizza-slice', 'Pizza, cheese', '2 slices', [568, 24, 66, 22, 3.6, 6, 1240], {
    cuisine: 'continental',
    tags: ['ultra-processed'],
    allergens: ['gluten', 'dairy'],
    vegetarian: true,
  }),
  food('beer', 'Beer', '330 mL', [143, 1.2, 11, 0, 0, 0, 14], {
    vegan: true,
    containsAlcohol: true,
    jainSafe: true,
  }),
  food('bacon', 'Bacon', '3 rashers', [161, 12, 0.6, 12, 0, 0, 581], {
    cuisine: 'american',
    tags: ['high-protein', 'ultra-processed'],
    containsPork: true,
  }),
];

const BY_ID = new Map(FOOD_DATABASE.map((item) => [item.id, item]));

export function findFood(id: string): FoodDefinition | null {
  return BY_ID.get(id) ?? null;
}

/**
 * Substring search over names, ranked so a prefix match beats a mid-word one.
 * Deliberately not fuzzy — a typo-tolerant matcher that silently logs "dal
 * makhani" when the user typed "dal makhni" is fine, but one that logs
 * "cheeseburger" for "chana" is not.
 */
export function searchFoods(query: string, limit = 20): FoodDefinition[] {
  const needle = query.trim().toLowerCase();
  if (needle.length === 0) return [];

  const scored: Array<{ item: FoodDefinition; score: number }> = [];
  for (const item of FOOD_DATABASE) {
    const name = item.name.toLowerCase();
    const index = name.indexOf(needle);
    if (index === -1) continue;
    scored.push({ item, score: index === 0 ? 0 : 1 + index });
  }

  return scored
    .sort((a, b) => a.score - b.score || a.item.name.localeCompare(b.item.name))
    .slice(0, limit)
    .map(({ item }) => item);
}

export function foodsByTag(tag: FoodTag): FoodDefinition[] {
  return FOOD_DATABASE.filter((item) => item.tags.includes(tag));
}

/**
 * Hard dietary compatibility. Returns the reason a food is excluded, or null
 * when it is safe to recommend — a string rather than a boolean because the UI
 * explains omissions ("hidden: contains dairy").
 */
export function dietaryConflict(
  item: FoodDefinition,
  input: { dietPattern: string; allergens: Allergen[] },
): string | null {
  for (const allergen of input.allergens) {
    if (item.allergens.includes(allergen)) return `contains ${allergen.replace('-', ' ')}`;
  }

  switch (input.dietPattern) {
    case 'vegetarian':
      if (!item.vegetarian) return 'not vegetarian';
      break;
    case 'eggetarian':
      if (!item.vegetarian && !item.allergens.includes('egg')) return 'not vegetarian';
      break;
    case 'vegan':
      if (!item.vegan) return 'not vegan';
      break;
    case 'pescatarian':
      if (!item.vegetarian && !item.allergens.includes('fish') && !item.allergens.includes('shellfish')) {
        return 'contains meat';
      }
      break;
    case 'halal':
      if (item.containsPork) return 'contains pork';
      if (item.containsAlcohol) return 'contains alcohol';
      break;
    case 'jain':
      if (!item.jainSafe) return 'not Jain-friendly';
      break;
    default:
      break;
  }

  return null;
}
