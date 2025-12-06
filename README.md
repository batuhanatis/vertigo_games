# Vertigo Games Data Analyst Case Study

## 📌 Project Summary
This project involves the simulation, strategic analysis, and user segmentation of a mobile game for Vertigo Games. The study is divided into two parts:
1.  **Task 1:** A/B Test Simulation & Revenue Projection (Using Oracle SQL).
2.  **Task 2:** Exploratory Data Analysis (EDA) & User Segmentation (Using Google BigQuery).
3.  
* **Tools Used:** Oracle SQL, Google BigQuery

---

# 📘 Task 1: A/B Test Simulation

### 🛠️ Methodology: Piecewise Exponential Model
To predict the 30-day retention curve based on limited data points (D1, D3, D7, D14), a **Piecewise Exponential Model** was implemented.

* **Why this method?** Unlike standard regression which approximates a curve, the Piecewise method ensures an **Exact Fit**. The simulation matches the provided D1, D3, D7, and D14 values with 100% accuracy.
* **Projection:** For D14-D30 (where no data exists), the decay rate from the last known segment (D7-D14) is applied.

* <img width="397" height="220" alt="image" src="https://github.com/user-attachments/assets/5a1498f6-7f61-498f-9092-ba07a4c89a12" />


### 📊 Key Findings (Based on Simulation Results)

#### 1. DAU Comparison (Day 15)
* **Winner: Variant B**
* **DAU A:** 54,626
* **DAU B:** 57,797
* **Insight:** While Variant A starts with higher retention (D1 53%), it suffers a severe drop-off between D7 and D14 (17% $\to$ 6%). Variant B retains users better in the mid-term (19% $\to$ 9%), allowing it to overtake Variant A in active users by Day 15.

<img width="400" height="225" alt="image" src="https://github.com/user-attachments/assets/a6e5bf42-74e5-4373-be53-d69252f5185d" />


#### 2. Cumulative Revenue (Day 15)
* **Winner: Variant B**
* **Rev A:** $192,058
* **Rev B:** $193,639
* **Insight:** Variant B has both a higher DAU count by this stage and a significantly higher eCPM ($10.80 vs $9.80), allowing it to generate more total revenue in the first two weeks.

#### 3. Long Term Revenue (Day 30)
* **Winner: Variant B (Decisive)**
* **Rev A:** $480,363
* **Rev B:** $519,472
* **Insight:** As time progresses, Variant B's superior "long-tail" retention widens the gap. By Day 30, Variant B generates **~8% more revenue** than Variant A.

### 💡 Strategic Recommendation (Question f)
**Priority: Option 2 (Add New User Source)**

* **Financial Comparison (Day 30 Snapshot):**
    * **Sale Scenario (Variant B):** $589,046
    * **New Source Scenario (Variant B):** $567,613
* **Decision:** Although the 10-Day Sale generates slightly more cash within this specific 30-day window, I recommend prioritizing the **New User Source**.
* **Reasoning:** The Sale is a temporary spike (10 days). The New User Source is a **permanent** addition to the ecosystem. Variant B's strong retention metrics prove it is excellent at holding onto users; feeding this efficient engine with a permanent stream of new users will yield a much higher Lifetime Value (LTV) and ROI over 60, 90, or 180 days compared to a one-time sale event.

* <img width="400" height="225" alt="image" src="https://github.com/user-attachments/assets/95b6a8c0-6cf6-4aad-adb4-81707f79e2c1" />


---

# 📙 Task 2: Exploratory Data Analysis (EDA)

### 🛠️ Methodology
Using **Google BigQuery**, raw user activity logs were analyzed to uncover behavioral trends. The analysis focused on four specific dimensions.

### 📊 Key Findings (Data-Driven Insights)

Based on the BigQuery results, the following patterns were identified:

#### A. Engagement Segmentation
* **Insight:** There is a massive correlation between Day 0 playtime and LTV.
* **High Engagement (>30m):** These users generate an average of **$0.73**, which is **~24x higher** than Low Engagement users ($0.03).
* **Retention Signal:** The win rate for High Engagement users is **69%**, whereas Low Engagement users have a win rate of **43%**. This suggests that users who lose frequently in their first session are likely to churn immediately.

* <img width="396" height="217" alt="image" src="https://github.com/user-attachments/assets/b370fc64-509e-4e66-9e79-40cae9adf603" />


#### B. Skill vs. Monetization
* **Insight:** "Casual Players" are the highest spenders, not the "Pros".
* **Casual Players (30-70% Win):** Average Revenue **$1.63**.
* **Pro Players (>70% Win):** Average Revenue **$0.89**.
* **Struggling Players (<30% Win):** Average Revenue **$0.41**.
* **Conclusion:** The game economy is likely driven by cosmetics or convenience items rather than "Pay-to-Win" mechanics. Pro players rely on skill, while Casual players are the most willing to spend to enhance their experience.

* <img width="401" height="213" alt="image" src="https://github.com/user-attachments/assets/efce918a-bd08-4805-9257-73883833d852" />


#### C. Spender Tier Analysis
* **Whale Behavior:** There are **3,564 Whales** (>$50 spenders) averaging **$193** LTV.
* **Ad Revenue:** Even Whales generate significant Ad Revenue ($0.65 avg), implying that ads are likely part of the core loop (e.g., rewarded videos) rather than just forced interstitials.
  
* <img width="395" height="206" alt="image" src="https://github.com/user-attachments/assets/157f26c8-5378-4823-a6ac-8f62d764b381" />

* **Game Balance:** The win rate difference between Whales (**59%**) and F2P players (**51%**) is small. This confirms the game is **balanced**; spending money does not guarantee a massive competitive advantage.
  
* <img width="401" height="205" alt="image" src="https://github.com/user-attachments/assets/6c4c8b37-9378-4cad-8575-0e57e87c9374" />

#### D. Weapon Playstyle (Bonus Analysis)
* *Note: Since weapon data was not present in the original dataset, this segment uses simulated data.*
* **Observation:** The metrics across Assault Rifles, Snipers, and SMGs are uniform (Avg Rev ~$0.45, Win Rate ~51%). In a real-world scenario, this query structure allows us to identify if specific weapons attract higher-paying users to target skin sales effectively.

---

## 🚀 How to Run the Code

### Task 1 (Oracle SQL)
1.  Open `src/Vertigo_games_task1.sql` in Oracle SQL Developer.
2.  Run the script to generate the daily projection table.

### Task 2 (BigQuery)
1.  Upload the dataset to Google BigQuery.
2.  Open `src/Vertigo_Games_Task2.sql`.
3.  Replace the table reference `` `vertigo_games.vertigo_games` `` with your project path.
4.  Run the query to generate the segmented report table shown above.

---

## 📂 Repository Structure
* `src/Vertigo_games_task1.sql`: A/B Test logic with Piecewise Exponential Model.
* `src/Vertigo_Games_Task2.sql`: User segmentation and behavioral analysis queries.
* `assets/`: Screenshots of query results and graphs.
* `README.md`: Project documentation.
