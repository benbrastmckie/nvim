# Budget Patterns

Budget formats, justification templates, and calculation patterns for different funder types.

## Overview

| Funder Type | Budget Format | Indirect Rate | Key Requirements |
|-------------|---------------|---------------|------------------|
| NSF | Standard NSF format | Negotiated | 2 pages justification |
| NIH | Modular or detailed | Negotiated | Depends on amount |
| Foundation | Simple categories | Often limited/excluded | One page typical |
| SBIR | Detailed | Limited rates | Phase-specific |

## Standard Budget Categories

### Personnel

```
Name          | Role          | % Effort | Salary   | Fringe   | Total
---------------------------------------------------------------------------
PI Name       | PI            | 10%      | $10,000  | $3,500   | $13,500
Staff Name    | Project Coord | 50%      | $25,000  | $8,750   | $33,750
TBN           | Research Asst | 100%     | $40,000  | $14,000  | $54,000
---------------------------------------------------------------------------
Personnel Total:                                               $101,250
```

### Fringe Benefits Calculation

```
Fringe Rate = [Institution rate, typically 25-40%]

Example: $50,000 salary x 35% fringe = $17,500 benefits
Total: $50,000 + $17,500 = $67,500
```

### Equipment

```
Item                 | Quantity | Unit Cost | Total   | Justification
---------------------------------------------------------------------------
Compute Server       | 1        | $15,000   | $15,000 | Required for ML training
Lab Equipment (spec) | 2        | $8,000    | $16,000 | Needed for experiments
---------------------------------------------------------------------------
Equipment Total:                             $31,000
```

### Travel

```
Trip Purpose        | # Trips | # People | Cost/Trip | Total
---------------------------------------------------------------------------
Conference (ACM)    | 1       | 2        | $2,000    | $4,000
Site Visit         | 2       | 1        | $800      | $1,600
Partner Meeting    | 4       | 1        | $500      | $2,000
---------------------------------------------------------------------------
Travel Total:                                        $7,600
```

### Other Direct Costs

```
Item                    | Cost    | Calculation/Justification
---------------------------------------------------------------------------
Publication fees        | $3,000  | 2 papers x $1,500 avg
Participant stipends    | $5,000  | 50 participants x $100
Software licenses       | $2,400  | $200/month x 12 months
Supplies               | $1,500  | Lab consumables estimate
---------------------------------------------------------------------------
Other Direct Total:     $11,900
```

## NSF Budget Pattern

### Page 1: Summary

```
A. Senior Personnel                          $XX,XXX
B. Other Personnel                           $XX,XXX
C. Fringe Benefits                           $XX,XXX
D. Equipment                                 $XX,XXX
E. Travel                                    $XX,XXX
F. Participant Support                       $XX,XXX
G. Other Direct Costs                        $XX,XXX
H. Total Direct Costs (A-G)                  $XX,XXX
I. Indirect Costs (rate% x MTDC)             $XX,XXX
J. Total Direct and Indirect Costs           $XX,XXX
```

### NSF Justification Template

```markdown
## A. Senior Personnel

**PI Name** (X calendar months at $X,XXX/month = $X,XXX)
Dr. Name will serve as PI, providing overall project direction,
supervising personnel, and leading [specific activities].

## B. Other Personnel

**Graduate Research Assistant** (Y calendar months at $X,XXX/month)
One graduate student will assist with [specific tasks] and will
gain training in [skills developed].

## C. Fringe Benefits
Fringe benefits are calculated at the institutionally negotiated
rate of XX% for faculty and XX% for graduate students.

## D. Equipment
[Item Name] ($X,XXX): Essential for [specific purpose]. [Explain
why purchase is necessary vs. using existing equipment.]

## E. Travel
**Domestic Travel** ($X,XXX): [N] trips to [destination/purpose]
at approximately $X,XXX per trip including airfare, lodging, and
per diem.

## F. Participant Support Costs
Not applicable to this proposal.

## G. Other Direct Costs
**Materials and Supplies** ($X,XXX): [Description of what will be
purchased and why needed.]

## H. Indirect Costs
Indirect costs are calculated at the federally negotiated rate of
XX% on modified total direct costs.
```

## NIH Budget Pattern

### Modular Budget (requests under $250K/year)

```
Direct Costs Per Year: $[125K/150K/175K/200K/225K/250K modules]
Number of Modules: [1-10]

Personnel Justification:
- PI: X effort, [role description]
- Key Personnel: Y effort, [role description]

Additional Budget Justification:
[Explain major cost categories briefly]
```

### Detailed Budget (requests over $250K/year)

```
Category                    Year 1    Year 2    Year 3    Total
-----------------------------------------------------------------
Personnel
  PI (X% effort)           $XX,XXX   $XX,XXX   $XX,XXX   $XXX,XXX
  Postdoc                  $XX,XXX   $XX,XXX   $XX,XXX   $XXX,XXX

Fringe Benefits            $XX,XXX   $XX,XXX   $XX,XXX   $XXX,XXX

Equipment                  $XX,XXX   $0        $0        $XX,XXX

Travel                     $X,XXX    $X,XXX    $X,XXX    $XX,XXX

Supplies                   $X,XXX    $X,XXX    $X,XXX    $XX,XXX

Other                      $X,XXX    $X,XXX    $X,XXX    $XX,XXX

Total Direct              $XXX,XXX  $XXX,XXX  $XXX,XXX  $XXX,XXX
Indirect (XX%)            $XX,XXX   $XX,XXX   $XX,XXX   $XXX,XXX
Total                     $XXX,XXX  $XXX,XXX  $XXX,XXX  $XXX,XXX
```

## Foundation Budget Pattern

### Simple Format

```markdown
## Project Budget

| Category          | Amount    |
|-------------------|-----------|
| Personnel         | $XX,XXX   |
| Consultants       | $X,XXX    |
| Travel            | $X,XXX    |
| Supplies/Equip    | $X,XXX    |
| Other             | $X,XXX    |
| **Total Request** | **$XX,XXX** |

### Personnel Detail
- Project Director (0.X FTE): $XX,XXX
- Program Coordinator (1.0 FTE): $XX,XXX
- Benefits (XX%): $XX,XXX

### Budget Narrative
[2-3 sentences per major category explaining the costs]
```

## SBIR Budget Pattern

### Phase I Budget (Typical $50K-275K)

```
Direct Labor                              Hours    Rate     Cost
-----------------------------------------------------------------
PI (Scientist)                            800      $75      $60,000
Engineer                                  500      $60      $30,000
Technician                                300      $40      $12,000
-----------------------------------------------------------------
Total Direct Labor                                          $102,000

Overhead (XXX%)                                             $XX,XXX
Materials                                                   $X,XXX
Consultants                                                 $X,XXX
Other Direct Costs                                          $X,XXX
-----------------------------------------------------------------
Total Phase I Request                                       $XXX,XXX
```

## Justification Patterns

### Personnel Justification

```
[Name/TBN], [Title] ([X]% effort, [Y] calendar months)

[Name] will serve as [role], responsible for [specific activities].
This level of effort is necessary because [rationale]. [Name]'s
qualifications include [relevant experience].

Salary: $X based on [institutional rate / market rate / position level]
Fringe: $X at XX% per institutional policy
Total: $X
```

### Equipment Justification

```
[Item Name] ($X,XXX)

This equipment is essential for [specific project activity]. It will
be used to [how it will be used]. Purchase is necessary because
[explain why existing equipment is insufficient]. The cost is based
on [quote/catalog price/market research].
```

### Travel Justification

```
[Conference/Site Visit] ($X,XXX total)

[Number] trip(s) to [destination] for [purpose]. This travel is
necessary to [benefit to project]. Each trip includes:
- Airfare: $XXX (based on current fares)
- Lodging: $XXX/night x X nights = $XXX
- Per diem: $XX/day x X days = $XXX
- Ground transportation: $XX
```

## Common Mistakes to Avoid

1. **Math errors**: Triple-check all calculations
2. **Missing fringe**: Always include benefits on personnel
3. **Unexplained items**: Every line needs justification
4. **Round numbers**: Avoid suspiciously round figures
5. **Indirect on excluded items**: Know what MTDC excludes
6. **Inflation assumptions**: State if multi-year budgets include increases

## Best Practices

1. **Match narrative**: Budget should directly support proposed activities
2. **Be specific**: "Supplies" is vague; "Lab reagents for X experiments" is clear
3. **Show calculations**: "3 trips x $800 = $2,400" not just "$2,400"
4. **Use institutional rates**: Verify fringe and indirect rates are current
5. **Leave modest contingency**: Build in small buffers where allowed
6. **Round appropriately**: Nearest $100 or $1,000 depending on scale

## Navigation

- [Proposal Structure](proposal-structure.md)
- [Evaluation Patterns](evaluation-patterns.md)
- [Narrative Patterns](narrative-patterns.md)
- [Parent Directory](../README.md)
