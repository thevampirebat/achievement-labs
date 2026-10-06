# Shared achievement totals

`achievement-totals.json` contains public title metadata and positive totals measured from complete Xbox achievement definition lists, excluding challenges. It contains no XUID, tokens, unlocked counts or account history. The catalogue contains 937 positive cached definition totals from the full successful-totals export supplied on 6 October 2026. It includes all 232 successful rows of the earlier partial scan report; their totals agree. For entries sourced from Cached definition total, checkedAt records the supplied cache snapshot timestamp, not a fresh Xbox query. Empty responses and unsuccessful/count-conflict rows are excluded.

The app bundles this catalogue and checks the public copy on this fork's main branch when connecting or refreshing the library. A successful download is cached for 24 hours; offline and invalid responses retain bundled/cached totals. Matching requires the exact Xbox Title ID and an overlapping listed platform. Existing Xbox/profile cache counts take priority. Shared counts fill missing totals; they never replace account progress. Titles with shared totals no longer need the missing-totals scan unless their account history conflicts with the count.

After merge, the online URL is:
https://raw.githubusercontent.com/thevampirebat/achievement-labs/main/catalog/achievement-totals.json

To gather every earlier successful scan without rescanning, use **Export verified totals** in the Xbox library. It joins the connected profile’s cached definition totals to the current library metadata, and exports only positive successful counts. This export includes earlier cached successes, not only the titles checked during the latest scan. The export does not upload anything automatically.

To add future scan results, export verified totals and run:

```sh
python tools/Import-SharedTotals.py achievement-verified-totals.csv --checked-at 2026-10-05T23:13:52Z
```

Use the actual scan timestamp. Review the catalogue diff and commit it to this fork's main branch through a pull request. Existing users receive the update on their next library refresh after the cache expires; new builds also include it. Nothing is automatically uploaded from users' accounts. Older scan reports can also be imported; those reports cover only their checked titles.
